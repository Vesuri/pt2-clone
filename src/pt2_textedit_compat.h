#pragma once
// Compatibility shims for old text-editing API (used by synth branch code)
#include "pt2_textedit.h"
#include "pt2_edit.h"

#define renderTextEditMarker()   renderTextEditCursor()
#define removeTextEditMarker()   removeTextEditCursor()
#define textCharNext()           editTextNextChar()
#define textCharPrevious()       editTextPrevChar()
#define getTextLine(obj)         enterTextEditMode(obj)
#define getNumLine(type, obj)    enterNumberEditMode(type, obj)
#define exitGetTextLine(update)  leaveTextEditMode(update)
#define updateTextObject(obj)    handleTextEditing(0)
