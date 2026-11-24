CREATE OR REPLACE PROCEDURE IT.PRT_ENV_WSI_CTA_TAR IS
   v_cta_error number := 0;
   v_tar_error number := 0;
   v_lin_error number := 0;
   v_respuesta varchar2(4000);
   v_nom_proceso varchar2(50) := 'PRT_ENV_WSI_CTA_TAR';
   v_cod_procesadora      ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('COD_PRO_BANCARD');
   v_nom_archivo          ge_par_entes.val_parametro%TYPE;
   v_err_code NUMBER(5);
   v_err_msj  VARCHAR2(4000);
   CURSOR cta_pend IS
      SELECT a.nro_tarjeta
        FROM ta_tar_nominadas a
       WHERE a.env_cuenta = 'N';
   CURSOR tar_pend IS
      SELECT a.nro_tarjeta
        FROM ta_tar_nominadas a
       WHERE a.env_tarjeta = 'N';
    -- cursor lineas de sobregiros pendientes
    CURSOR lin_pen IS
      SELECT a.nro_solicitud
        FROM ta_sol_lineas a
       WHERE a.env_bancard = 'N'
         and a.cod_estado = 'APR';
BEGIN
   --------Tarjetas--------
   Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
   FOR tar IN tar_pend LOOP
      v_respuesta := FUG_WSI_ABM_CLI_TAR(tar.nro_tarjeta);
      IF instr(upper(v_respuesta), 'SUBMITIDO') = 0 THEN
         v_tar_error := v_tar_error + 1;
      END IF;
   END LOOP;
   --------Cuentas---------
   FOR cta IN cta_pend LOOP
      v_respuesta := FUG_WSI_ABM_CLI_CTA(cta.nro_tarjeta);
      IF instr(upper(v_respuesta), 'SUBMITIDO') = 0 THEN
         v_cta_error := v_cta_error + 1;
      END IF;
   END LOOP;
   --Solicitud Lineas de Ampliación
   FOR lin IN lin_pen LOOP
      IF fue_obt_nom_ente(v_cod_procesadora) = 'BANCARD' THEN
	       v_nom_archivo := fug_obt_parentes(v_cod_procesadora, 'NOM_ARC_CTA_BANCARD');
	    ELSE
	       v_nom_archivo := fug_obt_parentes(v_cod_procesadora, 'NOM_ARCHIVO');
	    END IF;
	   	v_respuesta := fug_wsi_env_archivos(v_nom_archivo, v_cod_procesadora, lin.nro_solicitud);
	    IF instr(upper(v_respuesta), 'SUBMITIDO')  = 0 THEN
	   		 v_lin_error := v_lin_error + 1;
	    else
	   		 begin
           update ta_sol_lineas
              set env_bancard = 'S'
            where nro_solicitud = lin.nro_solicitud;
            commit;
         exception
           when others then
             pat_imp.pr_log(substr(v_nom_proceso ||'. No se ha podido actualizar el envio en la Solicitudes de Línea. '||sqlerrm,1,4000));
             --raise_application_error(-20000, 'No se ha podido actualizar el envio en la Solicitudes de Línea'||sqlerrm);
         end;
	   	END IF;
   END LOOP;


   IF v_cta_error > 0 AND v_tar_error > 0 THEN
      pat_imp.pr_log(v_nom_proceso ||'. Registros con errores: '||v_cta_error||' en Cuentas y '||v_tar_error||' en Tarjetas.');
      --raise_application_error(-20000, 'Registros con errores: '||v_cta_error||' en Cuentas y '||v_tar_error||' en Tarjetas.');
      INSERT INTO ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
      VALUES (811, 'PRT_ENV_WSI_CTA_TAR', sysdate, sysdate, 'Registros con errores: '||v_cta_error||' en Cuentas y '||v_tar_error||' en Tarjetas.');
   ELSIF v_cta_error > 0 THEN
      pat_imp.pr_log( v_nom_proceso ||'. Existen: '||v_cta_error||' registros con errores en Cuentas');
      --raise_application_error(-20000, 'Existen: '||v_cta_error||' registros con errores en Cuentas');
      INSERT INTO ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
      VALUES (811, 'PRT_ENV_WSI_CTA_TAR', sysdate, sysdate, ' Existen: '||v_cta_error||' registros con errores en Cuentas');
   ELSIF v_tar_error > 0 THEN
      pat_imp.pr_log( v_nom_proceso ||'. Existen: '||v_tar_error||' registros con errores en Tarjetas');
      --raise_application_error(-20000, 'Existen: '||v_tar_error||' registros con errores en Tarjetas');
      INSERT INTO ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
      VALUES (811, 'PRT_ENV_WSI_CTA_TAR', sysdate, sysdate, 'Existen: '||v_tar_error||' registros con errores en Tarjetas');
   END IF;

   IF v_lin_error > 0 THEN
      pat_imp.pr_log( v_nom_proceso ||'. Existen: '||v_lin_error||' registros con errores en Ampliación/Disminución de Líneas');
      INSERT INTO ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
      VALUES (811, 'PRT_ENV_WSI_CTA_TAR', sysdate, sysdate, 'Existen: '||v_lin_error||' registros con errores en Ampliación/Disminución de Líneas');
   END IF;
END PRT_ENV_WSI_CTA_TAR;
/

