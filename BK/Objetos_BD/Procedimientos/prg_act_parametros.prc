CREATE OR REPLACE PROCEDURE IT.PRG_ACT_PARAMETROS IS
  v_fecha date;

BEGIN
  -- Requerimiento: CIE-52
  -- Inicializo el programa.
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
  pag_cal.pr_obt_dat_calendar(1);
  v_fecha := pag_cal.G_ULT_DIA_MES_HABIL;
  
  --Actualizo a ultima fecha habil del mes.
  update ge_par_dinamicos
     set val_parametro = trunc(v_fecha)
   where parametro = 'FEC_CIE_MENSUAL';

  commit;
END;
/
