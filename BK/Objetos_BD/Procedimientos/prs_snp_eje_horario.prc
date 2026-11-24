CREATE OR REPLACE PROCEDURE IT.PRS_SNP_EJE_HORARIO is
  v_hor_inicio         ge_snp_horarios.hor_inicio%type := to_char((sysdate - 1/144),'hh24:mi:ss');-- Menos 10 minutos.
  v_hor_fin            ge_snp_horarios.hor_fin%type := to_char((sysdate + 1/144),'hh24:mi:ss'); --Mas 10 minutos.
  v_hor_eje_automatica ge_snp_horarios.hor_eje_automatica%type;
  v_msj_error          ge_snp_horarios.error%type;
   
  CURSOR cur_horario IS
    SELECT cod_periodo, det_sql, hor_eje_automatica 
      FROM ge_snp_horarios
     WHERE tip_horario = 'A'
       AND estado = 'E'
        or (estado = 'P' and pas_snp.g_fec_actual >= trunc(nvl(fecha,pas_snp.g_fec_actual)));

BEGIN
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; 
   FOR r IN cur_horario LOOP
     v_hor_eje_automatica := substr(r.hor_eje_automatica,1,2)||':'||substr(r.hor_eje_automatica,3,2);
     IF v_hor_eje_automatica BETWEEN v_hor_inicio AND v_hor_fin THEN
        IF r.det_sql IS NOT NULL THEN
           sql_util.ejecute_dml(r.det_sql,v_msj_error);
           IF v_msj_error IS NOT NULL THEN
              UPDATE ge_snp_horarios
                SET estado = 'E',
                    error = v_msj_error
                WHERE cod_periodo = r.cod_periodo;
           ELSE
              UPDATE ge_snp_horarios
                SET estado = 'P',
                    error = 'Proceso OK',
                    fecha = SYSDATE
                WHERE cod_periodo = r.cod_periodo;
           END IF;
        END IF;
     END IF;
   END LOOP;
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20001, 'Error en prs_snp_eje_horario: ' || SQLERRM);
END;
/

