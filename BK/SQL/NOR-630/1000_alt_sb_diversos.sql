ALTER TABLE it.sb_diversos 
ADD provisorio VARCHAR2(1) DEFAULT 'N';

-- Agregamos un comentario para que quien entre después sepa qué hace
COMMENT ON COLUMN it.sb_diversos.provisorio IS 'Indica origen de datos: S balance Consolidado, N balance Histórico';
