#! @file RequestIdentity.qc Opaque request ownership identity
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
/** Opaque immutable identity used to bind asynchronous tokens to their owning model.
    Equality is object identity. It has no mutable state or back-reference to a model,
    so retaining a request does not retain a widget/model or create a reference cycle.
    Applications carry it unchanged in returned request snapshots.
*/
public class RequestIdentity {}
}
