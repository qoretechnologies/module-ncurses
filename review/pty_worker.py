#!/usr/bin/env python3
"""Own one native story process and its PTY; relay control and terminal streams.

Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
"""
import argparse
import asyncio
import base64
import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import struct
import sys
import termios

ROOT = Path(__file__).resolve().parents[1]
LIMIT = 4 * 1024 * 1024


def emit(message):
    sys.stdout.write(json.dumps(message, ensure_ascii=False, separators=(',', ':')) + '\n')
    sys.stdout.flush()


def geometry(master, rows, cols):
    if type(rows) is not int or type(cols) is not int or not (1 <= rows <= 100 and 1 <= cols <= 240):
        raise ValueError('Geometry must be integer rows 1..100 and columns 1..240')
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))


async def run(args):
    master, slave = pty.openpty()
    process = None
    tasks = []
    input_transport = None
    loop = asyncio.get_running_loop()
    try:
        geometry(master, args.rows, args.cols)
        os.set_blocking(master, False)
        env = dict(os.environ, TERM='xterm-256color', LC_ALL='C.UTF-8', TZ='UTC')
        env['QORE_MODULE_DIR'] = f'{args.build_dir}:{ROOT / "qlib"}'
        process = await asyncio.create_subprocess_exec(
            args.qore, '-b', '--enable-debug', '--warnings-are-errors', str(ROOT / 'review/native.qr'),
            os.ttyname(slave), args.story, 'mono' if args.monochrome else 'color',
            cwd=ROOT, env=env, stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE, limit=LIMIT)
        emit({'type': 'process', 'pid': process.pid})
        # Keep the slave open until the native child opens it; otherwise the master
        # can report EIO before startup. Both descriptors are always released below.
        # Match the transport envelope, including sixfold JSON escape expansion.
        input_reader = asyncio.StreamReader(limit=128 * 1024)
        input_protocol = asyncio.StreamReaderProtocol(input_reader)
        input_transport, _ = await loop.connect_read_pipe(lambda: input_protocol, sys.stdin.buffer)
        terminal_done = loop.create_future()

        def read_terminal():
            try:
                data = os.read(master, 65536)
                if data:
                    emit({'type': 'terminal', 'data': base64.b64encode(data).decode('ascii')})
                else:
                    loop.remove_reader(master)
                    if not terminal_done.done():
                        terminal_done.set_result(None)
            except OSError as error:
                if error.errno == errno.EAGAIN:
                    return
                loop.remove_reader(master)
                if not terminal_done.done():
                    if error.errno == errno.EIO:
                        terminal_done.set_result(None)
                    else:
                        terminal_done.set_exception(error)
            except Exception as error:
                loop.remove_reader(master)
                if not terminal_done.done():
                    terminal_done.set_exception(error)

        loop.add_reader(master, read_terminal)

        async def write_terminal(data):
            view = memoryview(data)
            while view:
                try:
                    view = view[os.write(master, view):]
                except BlockingIOError:
                    ready = loop.create_future()
                    def writable():
                        if not ready.done():
                            ready.set_result(None)
                    loop.add_writer(master, writable)
                    try:
                        await ready
                    finally:
                        loop.remove_writer(master)

        async def controls():
            while line := await input_reader.readline():
                command = json.loads(line)
                if command.get('geometry'):
                    geometry(master, **command.pop('geometry'))
                data = command.pop('data', '')
                encoding = command.pop('encoding', 'utf8')
                if command.get('action') == 'input':
                    if encoding not in ('utf8', 'latin1') or not isinstance(data, str) or '\x1e' in data:
                        raise ValueError('Invalid input encoding or reserved review fence U+001E')
                    data = data.encode(encoding)
                    if len(data) > 16384:
                        raise ValueError('Input exceeds 16384 bytes')
                process.stdin.write((json.dumps(command) + '\n').encode())
                await process.stdin.drain()
                if command.get('action') == 'input':
                    await write_terminal(data + b'\x1e')
            process.stdin.close()

        async def frames():
            while line := await process.stdout.readline():
                emit(json.loads(line))

        async def diagnostics():
            while line := await process.stderr.readline():
                raise RuntimeError('Native diagnostic: ' + line.decode(errors='replace').rstrip())

        tasks = [asyncio.create_task(controls()), asyncio.create_task(frames()),
                 asyncio.create_task(diagnostics()), asyncio.create_task(process.wait())]
        # Completion or failure of any source is meaningful, never a timing/poll barrier.
        pending = set(tasks) | {terminal_done}
        while tasks[-1] in pending:
            done, pending = await asyncio.wait(pending, return_when=asyncio.FIRST_COMPLETED)
            for task in done:
                task.result()
            if terminal_done in done and not tasks[-1].done():
                raise RuntimeError('PTY closed before native process completion')
            if tasks[0] in done:
                # EOF/disconnect requests graceful native teardown, bounded below.
                await asyncio.wait_for(asyncio.shield(tasks[-1]), 3)
                break
        await tasks[1]
        if process.returncode:
            raise RuntimeError(f'Native process exited with status {process.returncode}')
        emit({'type': 'exit', 'code': process.returncode})
    finally:
        if input_transport:
            input_transport.close()
        loop.remove_reader(master)
        loop.remove_writer(master)
        for task in tasks:
            if not task.done():
                task.cancel()
        if process and process.returncode is None:
            if process.stdin:
                process.stdin.close()
            try:
                await asyncio.wait_for(process.wait(), 3)
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        os.close(slave)
        os.close(master)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--story', required=True)
    parser.add_argument('--rows', required=True, type=int)
    parser.add_argument('--cols', required=True, type=int)
    parser.add_argument('--monochrome', action='store_true')
    parser.add_argument('--build-dir', default=str(ROOT / 'build-debug'))
    parser.add_argument('--qore', default='qore')
    try:
        asyncio.run(run(parser.parse_args()))
    except Exception as error:
        emit({'type': 'error', 'fatal': True, 'error': str(error)})
        sys.exit(1)


if __name__ == '__main__':
    main()
