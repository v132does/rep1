CREATE OR REPLACE PROCEDURE IT.PRG_GEN_NOV_CUENTA
 (P_FECHA IN DATE
 ,P_HORA IN VARCHAR2
 ,p_cod_usuario in varchar2
 ,p_nro_cuenta in varchar2
 ,p_cod_modulo in number
 ,p_cod_modalidad in number
 ,p_est_anterior in varchar2
 ,p_est_nuevo in varchar
 ,p_fec_cam_est_ant in date)
 IS
BEGIN
    insert into ge_cuentas_nov
       (fecha, hora, cod_usuario,
        nro_cuenta, nro_detalle,
        cod_modulo, cod_modalidad,
        est_anterior, est_actual, fec_cam_est_ant)
    values
       (p_fecha, p_hora, p_cod_usuario,
        p_nro_cuenta, null,
        p_cod_modulo, p_cod_modalidad,
        p_est_anterior, p_est_nuevo, p_fec_cam_est_ant);
exception
  when others then
     raise_application_error(-20000,'PRg_GEN_NOV_CUENTA '||sqlerrm);
END;
/

