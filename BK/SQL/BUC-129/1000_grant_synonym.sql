CREATE OR REPLACE PUBLIC SYNONYM cr_per_tip_operaciones_tmp FOR it.cr_per_tip_operaciones_tmp;
GRANT ALL ON cr_per_tip_operaciones_tmp TO IT_TEMPORAL;

CREATE OR REPLACE PUBLIC SYNONYM prg_pro_per_tip_operaciones FOR it.prg_pro_per_tip_operaciones;
GRANT EXECUTE ON prg_pro_per_tip_operaciones TO IT_TEMPORAL;
