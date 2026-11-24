-- Agregar el campo 'programado'
ALTER TABLE IT.BA_TAB_DEPURADAS
ADD (programado VARCHAR2(1) DEFAULT 'N');

-- Agregar el comentario a la columna 'programado'
COMMENT ON COLUMN IT.BA_TAB_DEPURADAS.programado
IS 'Indica si la depuración se realizará en el job o en el cierre. N - se ejecuta desde el cierre, S - se ejecuta desde el job PASE_A_HISTORICO.';
