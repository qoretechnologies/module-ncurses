#! @file FormModel.qc Typed form values, validation and submission lifecycle
/* Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT */
public namespace NcursesUi {
#! State shared by forms and asynchronous action controls.
public enum ActionState : int { Pending = 0, Running = 1, Cancelled = 2, Failed = 3, Completed = 4 }
#! Supported generic form value types.
public enum FieldType : int { Text = 0, Multiline = 1, Password = 2, Integer = 3, Number = 4, Boolean = 5, Choice = 6 }
#! A stable choice value independent of its display label.
public hashdecl ChoiceItem {
    string value;
    string label;
    string description = "";
    string recommendation = "";
    bool disabled = False;
    bool default_value = False;
}
#! Field metadata and optional application validation; no network/schema dependency.
public hashdecl FormField {
    string name;
    string label;
    int type = NcursesUi::FieldType::Text;
    string help = "";
    bool required = False;
    bool read_only = False;
    auto default_value;
    list<hash<NcursesUi::ChoiceItem>> choices = ();
    *code<*string(auto)> validate;
}
#! An immutable request snapshot; its generation identifies a specific submission.
public hashdecl FormSubmission { int generation; hash<auto> values; }

/** UI-thread-owned form model with typed values and explicit action state.
    Editing is blocked during validation/submission and after completion. Cancellation
    invalidates the generation, so a delayed success/failure cannot overwrite newer state.
    Validation and submission failures preserve all entered values. Password values are
    returned only through the explicit value/submission APIs, never formatted into errors.
*/
public class FormModel {
    private {
        list<hash<NcursesUi::FormField>> fields = ();
        hash<string, int> positions = {};
        hash<auto> values = {};
        hash<string, string> errors = {};
        hash<string, string> control_errors = {};
        *code<hash<string, string>(hash<auto>)> form_validator;
        int state = NcursesUi::ActionState::Pending;
        int generation = 0;
        int revision = 0;
        int defaults_revision = 0;
        bool validating = False;
        *string failure;
        auto result;
    }
    /** Defines the fields and their typed defaults. @param definitions field metadata */
    constructor(list<hash<NcursesUi::FormField>> definitions = ()) { setFields(definitions); }
    /** Replaces the schema atomically, resetting values to defaults.
        @param definitions unique named fields @throw FORM-DEFINITION-ERROR for invalid metadata/defaults
    */
    nothing setFields(list<hash<NcursesUi::FormField>> definitions) {
        checkEditable(); hash<string, int> next_positions = {}; hash<auto> next_values = {};
        for (int i = 0; i < definitions.size(); ++i) {
            hash<NcursesUi::FormField> field = definitions[i];
            if (!field.name || exists next_positions{field.name} || field.type < NcursesUi::FieldType::Text
                    || field.type > NcursesUi::FieldType::Choice) { throw "FORM-DEFINITION-ERROR", "Invalid or duplicate field definition"; }
            hash<string, bool> options = {}; int defaults = 0;
            foreach hash<NcursesUi::ChoiceItem> option in (field.choices) {
                if (exists options{option.value}) { throw "FORM-DEFINITION-ERROR", "Duplicate choice value for " + field.name; }
                options{option.value} = True;
                if (option.default_value) {
                    if (option.disabled || ++defaults > 1) { throw "FORM-DEFINITION-ERROR", "Invalid default choice for " + field.name; }
                    if (!exists field.default_value) { field.default_value = option.value; }
                }
            }
            if (!typeValid(field, field.default_value)) { throw "FORM-DEFINITION-ERROR", "Invalid default type for " + field.name; }
            if (field.type == NcursesUi::FieldType::Choice && exists field.default_value) {
                bool valid = False;
                foreach hash<NcursesUi::ChoiceItem> option in (field.choices) { if (option.value == field.default_value && !option.disabled) { valid = True; break; } }
                if (!valid) { throw "FORM-DEFINITION-ERROR", "Unavailable default choice for " + field.name; }
            }
            definitions[i] = field; next_positions{field.name} = i; next_values{field.name} = field.default_value;
        }
        fields = definitions; positions = next_positions; values = next_values; errors = {}; control_errors = {}; failure = NOTHING;
        state = NcursesUi::ActionState::Pending; result = NOTHING; ++generation; ++revision; ++defaults_revision;
    }
    /** Returns field metadata. @return ordered definitions */
    list<hash<NcursesUi::FormField>> getFields() { return fields; }
    /** Returns typed entered values. @return named values, including explicitly requested password values */
    hash<auto> getValues() { return values; }
    /** Returns one typed value. @param name field name @return value @throw FORM-FIELD-ERROR if unknown */
    auto getValue(string name) { field(name); return values{name}; }
    /** Changes an editable field, clearing its previous error.
        @param name field name @param value typed value; NOTHING is an unset value
        @throw FORM-VALUE-ERROR for incompatible types @throw FORM-READONLY-ERROR for read-only fields
    */
    nothing setValue(string name, auto value) {
        checkEditable(); hash<NcursesUi::FormField> definition = field(name);
        if (definition.read_only) { throw "FORM-READONLY-ERROR", "Field is read-only: " + name; }
        if (!typeValid(definition, value)) { throw "FORM-VALUE-ERROR", "Invalid value type for " + name; }
        values{name} = value; remove errors{name}; remove control_errors{name}; failure = NOTHING; result = NOTHING;
        state = NcursesUi::ActionState::Pending; ++generation; ++revision;
    }
    /** Records a control's parse error without replacing its last typed value.
        @param name field name @param message plain error text, or NOTHING to clear
    */
    nothing setFieldError(string name, *string message) {
        checkEditable(); field(name);
        if (message) { errors{name} = message; control_errors{name} = message; }
        else { remove errors{name}; remove control_errors{name}; }
        ++revision;
    }
    /** Sets whole-form validation. @param callback returns field-name/errors, with empty key for a form error */
    nothing setValidator(*code<hash<string, string>(hash<auto>)> callback) { checkEditable(); form_validator = callback; ++revision; }
    /** Returns current errors. @return field name to error text; empty key is form-wide */
    hash<string, string> getErrors() { return errors; }
    /** Returns the first invalid field in schema order. @return name or NOTHING */
    *string firstInvalid() { foreach hash<NcursesUi::FormField> f in (fields) { if (exists errors{f.name}) { return f.name; } } return NOTHING; }
    /** Returns action state. @return ActionState */
    int getState() { return state; }
    /** Returns the latest failure message. @return failure or NOTHING */
    *string getFailure() { return failure; }
    /** Returns a successful submission result. @return caller-defined value */
    auto getResult() { return result; }
    /** Returns the model generation for repainting. @return monotonic revision */
    int getRevision() { return revision; }
    /** Reports explicit default restoration or schema replacement. @return monotonic revision */
    int getDefaultsRevision() { return defaults_revision; }
    /** Validates typed values and calls custom validators without permitting reentrant edits.
        @return True when valid; validation exceptions propagate and preserve entered values
    */
    bool validate() {
        checkEditable(); validating = True; on_exit validating = False;
        hash<string, string> next = control_errors;
        foreach hash<NcursesUi::FormField> f in (fields) {
            if (exists control_errors{f.name}) { continue; }
            auto value = values{f.name}; *string error;
            if (f.required && (!exists value || (value.typeCode() == NT_STRING && string(value) =~ /\A\s*\z/))) {
                error = "Required";
            } else if (exists value && f.type == NcursesUi::FieldType::Choice) {
                bool found = False;
                foreach hash<NcursesUi::ChoiceItem> option in (f.choices) { if (value == option.value && !option.disabled) { found = True; break; } }
                if (!found) { error = "Choose an available value"; }
            }
            if (!error && f.validate) { error = f.validate(value); }
            if (error) { next{f.name} = error; }
        }
        if (form_validator && !control_errors) {
            hash<string, string> extra = form_validator(values);
            foreach hash<string, auto> item in (extra.pairIterator()) {
                if (item.key != "" && !exists positions{item.key}) { throw "FORM-VALIDATOR-ERROR", "Validator returned an unknown field"; }
                next{item.key} = string(item.value);
            }
        }
        errors = next; ++revision; return !errors;
    }
    /** Starts a submission after validation. @return immutable token or NOTHING if validation failed */
    *hash<NcursesUi::FormSubmission> beginSubmit() {
        checkEditable(); if (!validate()) { return NOTHING; }
        state = NcursesUi::ActionState::Running; failure = NOTHING; ++revision;
        return <NcursesUi::FormSubmission>{"generation": ++generation, "values": values};
    }
    /** Commits a matching asynchronous success; stale generations are ignored.
        @param token submission generation @param value caller-defined result @return True if accepted
    */
    bool complete(int token, auto value) {
        if (state != NcursesUi::ActionState::Running || token != generation) { return False; }
        state = NcursesUi::ActionState::Completed; result = value; ++revision; return True;
    }
    /** Commits a matching asynchronous failure. @param token generation @param message error text @return accepted */
    bool fail(int token, string message) {
        if (state != NcursesUi::ActionState::Running || token != generation) { return False; }
        state = NcursesUi::ActionState::Failed; failure = message; ++revision; return True;
    }
    /** Runs a synchronous submit callback; errors are recorded and propagated.
        @param callback receives typed values @return True if completed, False for validation failure or cancellation
    */
    bool submit(code<auto(hash<auto>)> callback) {
        *hash<NcursesUi::FormSubmission> request = beginSubmit(); if (!request) { return False; }
        try { auto value = callback(request.values); return complete(request.generation, value); }
        catch (hash<ExceptionInfo> ex) { fail(request.generation, ex.desc); rethrow; }
    }
    /** Cancels pending/running work and invalidates outstanding generations. Completed forms stay completed. */
    nothing cancel() {
        if (validating) { throw "FORM-BUSY-ERROR", "Cannot cancel during validation"; }
        if (state == NcursesUi::ActionState::Completed) { return; }
        state = NcursesUi::ActionState::Cancelled; ++generation; ++revision;
    }
    /** Reopens the form, preserving values unless defaults are explicitly requested. @param defaults restore defaults */
    nothing reset(bool defaults = False) {
        if (validating || state == NcursesUi::ActionState::Running) { throw "FORM-BUSY-ERROR", "Cannot reset an active form"; }
        if (defaults) { foreach hash<NcursesUi::FormField> f in (fields) { values{f.name} = f.default_value; } ++defaults_revision; }
        errors = {}; control_errors = {}; failure = NOTHING; result = NOTHING; state = NcursesUi::ActionState::Pending; ++generation; ++revision;
    }
    private hash<NcursesUi::FormField> field(string name) {
        if (!exists positions{name}) { throw "FORM-FIELD-ERROR", "Unknown form field: " + name; }
        return fields[positions{name}];
    }
    private nothing checkEditable() {
        if (validating || state == NcursesUi::ActionState::Running || state == NcursesUi::ActionState::Completed) {
            throw "FORM-BUSY-ERROR", "Form is validating, submitting or completed";
        }
    }
    private static bool typeValid(hash<NcursesUi::FormField> field, auto value) {
        if (!exists value) { return True; }
        if (field.type == NcursesUi::FieldType::Boolean) { return value.typeCode() == NT_BOOLEAN; }
        if (field.type == NcursesUi::FieldType::Integer) { return value.typeCode() == NT_INT; }
        if (field.type == NcursesUi::FieldType::Number) { return value.typeCode() == NT_INT || ((value.typeCode() == NT_FLOAT || value.typeCode() == NT_NUMBER) && !value.nanp() && !value.infp()); }
        return value.typeCode() == NT_STRING;
    }
}
} # namespace NcursesUi
