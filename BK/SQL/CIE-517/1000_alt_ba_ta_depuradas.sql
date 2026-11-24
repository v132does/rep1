-- 1. Añadir la columna
ALTER TABLE it.ba_tab_depuradas ADD ( niv_paralell   number(8));
-- 2. Añadir el comentario
COMMENT ON COLUMN it.ba_tab_depuradas.niv_paralell IS 'Indica la cantidad de hilos de jobs para el dbms_parallel';
