CREATE OR REPLACE PROCEDURE IT.prt_ins_cor_gp(p_fec_cierre     IN it.ta_ext_cli_cab_gp.fec_cierre%TYPE,
                                              p_con_movimiento IN it.ta_ext_cli_cab_gp.con_movimiento%TYPE,
                                              p_cod_error      OUT NUMBER) IS
  r_log ta_logs_gp%ROWTYPE;
BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  r_log.nom_proceso    := 'PRT_INS_COR_GP';
  r_log.fec_hor_ini    := SYSDATE;
  p_cod_error          := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);

    INSERT INTO ba_env_correos_gp
      (nro_correo,
       tip_producto,
       fec_registro,
       estado,
       cod_persona,
       mai_destinatario)
      SELECT (ROWNUM +
             NVL((SELECT MAX(nro_correo) FROM ba_env_correos_gp), 0)) nro_fila,
             x.tip_producto,
             x.fec_cierre,
             x.estado,
             x.cod_persona,
             x.mail
        FROM (SELECT DISTINCT '37' tip_producto,
                              trunc(p_fec_cierre) fec_cierre,
                              'P' estado,
                              b.cod_persona,
                              nvl(c.dir_correo, 'Sin mail') mail
                FROM ta_ext_cli_cab_gp a, ge_cta_clientes b, ba_personas c
               WHERE fec_cierre = trunc(p_fec_cierre)
                 AND con_movimiento = p_con_movimiento
                 AND a.nro_cuenta = b.nro_cuenta
                 AND b.cod_persona = c.cod_persona
                 AND NOT EXISTS
                     (SELECT 1
                        FROM ba_env_correos_gp g
                       WHERE g.cod_persona = b.cod_persona
                         AND g.fec_registro = p_fec_cierre)) x;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error      := 999;
      r_log.men_error  := 'Error al insertar ba_env_correos_gp';
      r_log.nro_error  := p_cod_error;
      r_log.comentario := substr('Error al insertar ba_env_correos_gp, fecha_cierre:' ||
                                 p_fec_cierre || '-' || SQLERRM,
                                 1,
                                 500);
      pat_igp.pr_ins_log(r_log);
END;
/
