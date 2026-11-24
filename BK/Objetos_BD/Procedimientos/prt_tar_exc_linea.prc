CREATE OR REPLACE PROCEDURE IT.PRT_TAR_EXC_LINEA IS
 --DYDMR-12690 - se agrega la inserción de log
   v_result NUMBER(3) ;
   v_err_code NUMBER(5);
   v_err_msj  VARCHAR2(4000);
   v_hini_notifi ge_ra_log_mail.hor_inicio%type;
   v_hfin_notifi ge_ra_log_mail.hor_fin%type;
BEGIN
   v_hini_notifi := to_char(sysdate, 'hh24:mi:ss');
   v_result :=  PAW_NOT.fu_tar_exc_linea;
   v_hfin_notifi := to_char(sysdate, 'hh24:mi:ss');
   if v_result != 0 then
      v_err_code := nvl(SQLCODE,99998);
      v_err_msj  := nvl(substr(SQLERRM,4000),'Error en el proceso PRT_TAR_EXC_LINEA');
       INSERT INTO ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, nro_error, men_error)
            VALUES (972, 'PAW_NOT.FU_TAR_EXC_LINEA', v_hini_notifi, v_hfin_notifi, v_err_code, v_err_msj);
   end if;
  EXCEPTION
    WHEN OTHERS THEN
      v_err_code := nvl(SQLCODE,99999);
      v_err_msj  := nvl(substr(SQLERRM,4000),'Error en el proceso PRT_TAR_EXC_LINEA');
      INSERT INTO ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, nro_error, men_error)
           VALUES (972, 'PAW_NOT.FU_TAR_EXC_LINEA', v_hini_notifi, v_hfin_notifi, v_err_code, v_err_msj);
 END PRT_TAR_EXC_LINEA;
/

