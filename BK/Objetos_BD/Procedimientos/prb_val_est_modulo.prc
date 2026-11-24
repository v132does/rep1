CREATE OR REPLACE PROCEDURE IT.PRB_VAL_EST_MODULO
IS
-- Variables.
v_est_proceso ba_modulos.estado%type;
v_cod_modulo  ge_modalidades.cod_modulo%type := 2;
BEGIN
   -- Valida que el modulo de contabilidad ese cerrado.
   v_est_proceso := pae_cnf.fu_obt_est_modulo(v_cod_modulo);
   IF nvl(v_est_proceso,2) <> 4 THEN
      raise_application_error(-20000,'El modulo '||to_char(v_cod_modulo)||' debe estar cerrado para ejercutar el proceso');
   END IF;
END;
/

