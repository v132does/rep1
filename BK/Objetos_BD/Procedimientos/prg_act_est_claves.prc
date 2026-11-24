CREATE OR REPLACE PROCEDURE IT.prg_act_est_claves IS
  v_dias       NUMBER;
  v_fec_actual bw_ope_claves.fec_est_clave%type := pag_cal.fu_obt_fec_actual(1);
BEGIN
  --Anula las claves que no hayan sido activadas pasado el plazo definido en el parámetro ACT_CLA_PLZ_DIAS.
  v_dias := to_number(fug_obt_pardinamico('ACT_CLA_PLZ_DIAS'));
  UPDATE bw_ope_claves a
     SET a.est_clave = 'X', a.fec_est_clave = v_fec_actual
   WHERE a.est_clave = 'I'
     AND (fuh_obt_dif_dias(trunc(a.fec_impresion), v_fec_actual)) > v_dias;
  UPDATE ge_clientes b
     SET b.est_clave = 'X', b.fec_est_clave = v_fec_actual
   WHERE b.est_clave = 'I'
     AND (fuh_obt_dif_dias(trunc(b.fec_imp_clave), v_fec_actual)) > v_dias;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'Error en PRG_ACT_EST_CLAVES. ' || SQLERRM);
END;
/

