create or replace PROCEDURE    IT.prp_act_gar_hip_res12 IS

  v_cod_gar_hip_vivienda     pr_garantias.cod_garantia%type := fug_obt_pardinamico('COD_GAR_HIP_VIVIENDA', 6);
  v_can_dia_vencido          number(5) := nvl(to_number(fug_obt_pardinamico('CAN_DIA_MOR_RES12')), 60);
  v_fec_actual               ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(1);
  -- FIELDESK-165412
  v_ano_tas_res12            number(5) := nvl(to_number(fug_obt_pardinamico('VAL_ANO_TAS_HIP_RES12')), 3);
  v_fec_vto_tasacion         pr_gar_hipotecarias.fec_vencimiento%TYPE; -- vencimiento de tasacion vigente
  v_vencida                  BOOLEAN; -- tasacion o escritura vencida

CURSOR c_garantia IS
  SELECT h.nro_garantia,
         h.fec_vencimiento fec_vto_hipoteca,
         w.fec_vencimiento fec_vto_garantia,
         h.fec_ult_tasacion,                       -- FIELDESK-165412
         nvl(max(p.dia_atraso), 0) atraso,
         w.estado,
         w.cod_persona
    FROM pr_gar_hipotecarias h, pr_garantias w, pr_cta_garantias g, pr_cta_prestamos p
   WHERE w.nro_garantia = h.nro_garantia
     AND w.cod_garantia = v_cod_gar_hip_vivienda
     AND g.nro_garantia = w.nro_garantia
     AND g.cod_garantia = w.cod_garantia
     AND g.nro_cuenta   = p.nro_cuenta
     AND p.estado       <> 'N'
     AND (nvl(fug_obt_pardinamico('MAD_HIPOTECARIOS', p.cod_modulo, p.cod_modalidad), 'N') = 'S' OR
          nvl(fug_obt_pardinamico('PRE_MAD_CONSTRUCCIONES', p.cod_modulo, p.cod_modalidad), 'N') = 'S')
   GROUP BY h.nro_garantia, h.fec_vencimiento, w.fec_vencimiento, h.fec_ult_tasacion, w.estado, w.cod_persona;
BEGIN
  BEGIN   PRE_INI_APLICACION;   PAE_CNF.G_COD_MODULO := 1;  END;
  FOR x IN c_garantia LOOP
       v_fec_vto_tasacion := x.fec_vto_hipoteca;
 --   IF x.fec_vto_hipoteca = x.fec_vto_garantia THEN
       IF x.atraso > v_can_dia_vencido THEN
          -- FIELDESK-165412: con mora mayor al parametro, la vigencia de la tasacion es
          -- ultima tasacion + VAL_ANO_TAS_HIP_RES12 anios (3 si el parametro no esta cargado).
          -- Se recalcula cada cierre, asi que una tasacion nueva toma esa vigencia.
          v_fec_vto_tasacion := add_months(x.fec_ult_tasacion, v_ano_tas_res12 * 12);
          UPDATE pr_gar_hipotecarias h
             SET h.fec_vencimiento = v_fec_vto_tasacion
           WHERE h.nro_garantia = x.nro_garantia;
       END IF;
 --   ELSE
       IF x.atraso <= v_can_dia_vencido THEN
	    /*  ---
          UPDATE pr_gar_hipotecarias h
             SET h.fec_vencimiento = x.fec_vto_garantia
           WHERE h.nro_garantia = x.nro_garantia;
		  ---*/
          update cr_per_propiedades
             set hipotecado = 'S'
           where cod_persona = x.cod_persona
             and exists (select pr_gar_hipotecarias.nro_finca
                           from pr_gar_hipotecarias
                          where pr_gar_hipotecarias.nro_finca = cr_per_propiedades.nro_finca
                            and pr_gar_hipotecarias.nro_garantia = x.nro_garantia);
       END IF;
   -- END IF;

       -- FIELDESK-165412: si vencio la tasacion o la escritura, la garantia queda Vencida.
       -- Una garantia Vencida vuelve a Confirmada solo cuando la tasacion y la escritura
       -- estan vigentes (por ejemplo, despues de actualizar la tasacion), con cualquier mora.
       v_vencida := nvl(v_fec_vto_tasacion, DATE '9999-12-31') <= TRUNC(v_fec_actual)
                 OR nvl(x.fec_vto_garantia, DATE '9999-12-31') <= TRUNC(v_fec_actual);

       IF x.estado = 'V' AND NOT v_vencida AND v_fec_vto_tasacion IS NOT NULL THEN
          UPDATE pr_garantias h
             SET h.estado = 'C'
           WHERE h.nro_garantia = x.nro_garantia;
		 -- FIELDESK-165412: al reconfirmar la garantia se marca la propiedad como hipotecada
          update cr_per_propiedades
             set hipotecado = 'S'
           where cod_persona = x.cod_persona
             and exists (select pr_gar_hipotecarias.nro_finca
                           from pr_gar_hipotecarias
                          where pr_gar_hipotecarias.nro_finca = cr_per_propiedades.nro_finca
                            and pr_gar_hipotecarias.nro_garantia = x.nro_garantia);
       END IF;
  END LOOP;
  COMMIT;
END;
/