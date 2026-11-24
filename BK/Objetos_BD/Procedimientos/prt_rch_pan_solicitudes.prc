create or replace procedure it.PRT_RCH_PAN_SOLICITUDES is
  v_fec_actual DATE := pag_cal.fu_obt_fec_actual(5);--trunc(sysdate);
  v_can_dias number := fug_obt_pardinamico('TAR_CAN_DIA_PAN');
  v_cod_cau_sistema ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_SISTEMA');
  v_lin_sugerida cr_pun_lin_sugeridas.lin_sugerida%type;
  v_est_sugerido cr_pun_lin_sugeridas.est_sugerido%type;
  v_cod_puntaje cr_pun_lin_sugeridas.cod_puntaje%type;
  v_observacion ta_solicitudes.observacion%type;

  CURSOR c_solicitudes IS
  SELECT  tipo, t.cod_modulo, t.cod_modalidad, t.nro_solicitud, t.cod_campana, t.cod_canal,
          t.cod_moneda, t.puntaje, t.nro_linea
    from tv_solicitudes t
   where trunc(t.fec_solicitud + v_can_dias) <= v_fec_actual
     and t.cod_estado = 'PAN';
BEGIN
    v_observacion := '* ' || USER || '-' || to_char(v_fec_actual, 'DD/MM/YYYY' ) || ' => ' || 'Rechazado por Sistema';

    FOR s IN c_solicitudes LOOP
      begin
        select cod_puntaje
          into v_cod_puntaje
          from ge_sol_puntajes
         where cod_modulo = s.cod_modulo
           and nvl(cod_modalidad,nvl(s.cod_modalidad,-1)) = nvl(s.cod_modalidad,-1)
           and nvl(cod_campana,nvl(s.cod_campana,-1)) = nvl(s.cod_campana,-1)
           and nvl(cod_canal,nvl(s.cod_canal,-1)) = nvl(s.cod_canal,-1);
      exception
        when others then
          v_cod_puntaje := null;
      end;

      if s.tipo = 'T' then
        if s.puntaje is not null then
           BEGIN
             select lin_sugerida, est_sugerido
               into v_lin_sugerida, v_est_sugerido
               from cr_pun_lin_sugeridas
              where cod_puntaje = v_cod_puntaje
                and cod_moneda = cod_moneda
                and s.PUNTAJE between pun_desde and pun_hasta;
           EXCEPTION
             WHEN OTHERS THEN
               v_lin_sugerida := null;
               v_est_sugerido := null;
           END;
        end if;
        BEGIN
           Update ta_solicitudes t
              set cod_estado       = 'RCH',
                  cod_causa        = v_cod_cau_sistema,
                  cod_est_sugerido = v_est_sugerido,
                  lin_sugerida     = v_lin_sugerida,
                  observacion      = v_observacion,
                  niv_aprobacion   = null,
                  nro_acta         = null,
                  mto_aprobado     = nvl(t.mto_aprobado, t.monto),
                  fec_aprobacion	 = null
            WHERE nro_solicitud = s.nro_solicitud;
         EXCEPTION
            when others then
              null;
         END;
         BEGIN
         	 Update ta_sol_adicionales
						  set cod_estado     = 'RCH',
						      observacion    = v_observacion,
						      cod_causa      = v_cod_cau_sistema,
						      niv_aprobacion   = null,
						      nro_acta         = null,
						      fec_aprobacion	 = null
						where nro_solicitud  = s.nro_solicitud;
         EXCEPTION
           when others then
             null;
         END;
       elsif s.tipo = 'L' then
				 UPDATE ta_sol_lineas
					 	SET cod_estado = 'RCH',
					 	   	cod_causa	= v_cod_cau_sistema,
					 	    observacion    = v_observacion,
						    niv_aprobacion = null,
						    nro_acta       = null,
						    fec_aprobacion	= null
				  WHERE nro_solicitud = s.nro_solicitud;
       else
         BEGIN
         	 Update ta_sol_adicionales
						  set cod_estado     = 'RCH',
						      observacion    = v_observacion,
						      cod_causa      = v_cod_cau_sistema,
						      niv_aprobacion   = null,
						      nro_acta         = null,
						      fec_aprobacion	 = null
						where nro_solicitud  = s.nro_solicitud;
         EXCEPTION
           when others then
             null;
         END;
       end if;
    END LOOP;
    BEGIN
      Update ta_sol_adicionales t
				 set cod_estado     = 'RCH',
				     observacion    = v_observacion,
						 cod_causa      = v_cod_cau_sistema,
						 niv_aprobacion   = null,
						 nro_acta         = null,
						 fec_aprobacion	 = null
			 where nro_solicitud  is null
         and trunc(t.fec_ingreso + v_can_dias) <= v_fec_actual
         and t.cod_estado = 'PAN';
     EXCEPTION
       when others then
          null;
     END;

END PRT_RCH_PAN_SOLICITUDES;
/

