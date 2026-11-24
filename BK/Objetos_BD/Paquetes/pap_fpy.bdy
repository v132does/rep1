create or replace package body it.pap_fpy is

FUNCTION fu_obt_mto_fac_anual(p_cod_persona in varchar2,
                              p_mensaje in out varchar2)
return number
is
 v_fec_actual          ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_anho                cr_per_dat_segmentacion.ano_facturacion%type;
  v_mes                 cr_per_dat_segmentacion.mes_facturacion%type;
  v_mto_facturacion     cr_per_dat_segmentacion.mto_facturacion%type := 0;
  v_estado              cr_per_dat_segmentacion.estado%type;
  v_cod_act_primaria    ba_personas.cod_rub_primario%type;
  v_mensaje             varchar2(4000);
  v_tip_persona         ba_personas.tipo%type;
  v_nro_trimestre       ge_Calendarios.Nro_Trimestre%type;

BEGIN
  -- obtengo el numero de trimestre en la que estamos
  select nro_trimestre
  into v_nro_trimestre
   from ge_calendarios
  where cod_modulo = 1;

  --Obtengo la actividad principal del cliente.
  BEGIN
     SELECT a.cod_rub_primario, tipo
       INTO v_cod_act_primaria, v_tip_persona
       FROM ba_personas a
      WHERE a.cod_persona = p_cod_persona;

     if v_cod_act_primaria is null then
        v_mensaje := 'Registre la actividad primaria del Cliente.';
     end if;
  EXCEPTION
    WHEN OTHERS THEN
      v_mensaje := 'No se encuentra datos del Cliente.';
  END;

  -- obtengo los datos de la ultima facturacion registrada para el cliente para su actividad principal
  if v_mensaje is null then
    begin
      SELECT cp.ano_facturacion, cp.mes_facturacion, cp.estado, cp.mto_facturacion
        INTO v_anho, v_mes, v_estado, v_mto_facturacion
        FROM cr_per_dat_segmentacion cp
      WHERE cp.cod_persona = p_cod_persona
        AND cp.cod_rub_primario = v_cod_act_primaria
        AND to_date(cp.ano_facturacion||cp.mes_facturacion,'yyyymm') =
            (SELECT MAX(to_date(cp1.ano_facturacion||cp1.mes_facturacion,'yyyymm')) FROM cr_per_dat_segmentacion cp1 WHERE cp1.cod_persona = cp.cod_persona AND cp1.cod_rub_primario = cp.cod_rub_primario);
    exception
       when others then
           v_mensaje := 'Registrar los datos de la facturacion.(Opcion:Carpeta de la Persona/Pestaña:Facturacion)';
    end;
  end if;

  if v_mensaje is null then
     if v_anho = to_char(v_fec_actual, 'yyyy') - 1 then  -- si tiene registrado su facturacion del ultimo a?o
         if nvl(v_estado, 'N') = 'V' then -- si esta verificado entonces retorno
               return v_mto_facturacion;
         else
           v_mensaje := 'Los datos de Facturacion correspondiente al año '||v_anho||' no fueron verificados (Opcion:Carpeta de la Persona/Pestaña:Facturacion).';
         end if;
     else
        if v_nro_trimestre = 3 then -- hasta el primer trimestre es el periodo para presentar el balance cerrado del a?o anterior.
             if v_anho = to_char(v_fec_actual, 'yyyy') - 2 then
                  if nvl(v_estado, 'N') = 'V' then -- si esta verificado entonces retorno
                     return v_mto_facturacion;
                 else
                   v_mensaje := 'Los Datos de Facturacion correspondiente al año '||v_anho||' no fueron verificados (Opcion:Carpeta de la Persona/Pestaña:Facturacion).';
                 end if;
            else -- si ya pas
               v_mensaje := 'Registrar el monto de la ultima facturacion anual.(Opcion:Carpeta de la Persona/Pestaña:Facturacion)';
            end if;
        else   -- si ya paso del primer trimestre del a?o ya debe tener balance
               v_mensaje := 'Registrar el monto de facturacion anual del año cerrado.(Opcion:Carpeta de la Persona/Pestaña:Facturacion)';
        end if;
     end if;
  end if;

 p_mensaje := v_mensaje;
 return 0;

exception
   when others then
     p_mensaje := substr(v_mensaje ||'-'||sqlerrm,1,4000);
     return 0;
END;


-- valida monto minimo y monto maximo permitido
-- p_tip_valor: valores posible MIN = Para validar monto minimo; MAX, para validar monto maximo
FUNCTION fu_val_mto_sol_credito(p_cod_modalidad in pr_solicitudes.cod_modalidad%type,
                                p_cod_sub_modalidad in pr_solicitudes.cod_sub_modalidad%type,
                                p_monto in pr_solicitudes.monto%type,
                                p_tip_valor in varchar2)
return boolean
IS
v_mto_min_sol		number(18,2) := to_number(FUG_OBT_PARDINAMICO('MTO_MIN_SOL_FOGAPY',6, p_cod_modalidad, NULL, NULL,p_cod_sub_modalidad));
v_mto_max_sol		number(18,2) := to_number(FUG_OBT_PARDINAMICO('MTO_MAX_SOL_FOGAPY',6, p_cod_modalidad, NULL, NULL,p_cod_sub_modalidad));
BEGIN
  -- si el monto de la solicitud es menor al minimo requerido retornara false
  if p_tip_valor ='MIN' then
    if p_monto < v_mto_min_sol then
       return false;
    else
       return true;
    end if;

  -- si el monto de la solicitud es superior al monto maximo retornara false
  elsif p_tip_valor ='MAX' then
    if p_monto > v_mto_max_sol  then
       return false;
    else
       return true;
    end if;
  else
    return false;
  end if;

END;

-------------------------------------------------------------------------------
-----------
-------------------------------------------------------------------------------
FUNCTION fu_val_facturacion(p_cod_persona in pr_solicitudes.cod_persona%type,
                            p_cod_moneda in pr_solicitudes.cod_moneda%type,
                            p_monto in pr_solicitudes.monto%type,
                            p_cod_modalidad in pr_solicitudes.cod_modalidad%type,
                            p_cod_sub_modalidad in pr_solicitudes.cod_sub_modalidad%type
                            )
return varchar2
is
v_val_tasa     ge_tas_rangos.val_tasa%type;
v_fec_vigencia date;
v_tip_valor    ge_tasas.tip_valor%type;
v_tipo         ge_tasas.tipo%type;
v_cod_tasa     ge_tasas.cod_tasa%type := to_number(FUG_OBT_PARDINAMICO('COD_TAS_MTO_FOGAPY'));
v_fec_actual   date := pag_cal.FU_OBT_FEC_ACTUAL(1);
v_mto_facturacion     cr_per_dat_segmentacion.mto_facturacion%type := 0;
v_mensaje      varchar2(4000):='OK';
v_mto_max_fac  number(18,2):=0;
v_lugar        varchar2(150);
begin

  -- obtengo el monto de facturacion del cliente
  v_lugar:= 'Exec fug_obt_mto_fac_anual';
  v_mto_facturacion := pap_fpy.fu_obt_mto_fac_anual(P_COD_PERSONA, v_mensaje);
  ---
  if v_mensaje <> 'OK' then
     return v_mensaje;
  else
     --
     --  obtengo el monto de facturacion segun el monto solicitado
     --
     begin
       v_lugar:= 'Exec pag_gen';
        pag_gen.pr_obt_val_tasa(6,
                             p_cod_modalidad,
                             null, /*p_cod_oficina*/
                             NULL /*cuenta*/,
                             p_cod_moneda,
                             p_monto /*monto*/,
                             'S' /*tasa es personalizada*/,
                             v_cod_tasa,
                             NULL/*transac*/,
                             v_fec_actual,
                             v_val_tasa,
                             v_fec_vigencia,
                             v_tip_valor,
                             v_tipo,
                             p_cod_persona,
                             p_cod_sub_modalidad);


          if v_mto_facturacion > v_val_tasa then -- si la facturacion anual se encuentra dentro del rango definido
             v_mensaje:= 'La facturacion anual maxima para este tipo de prestamo '||fug_obt_des_submodalidad(6,p_cod_modalidad,p_cod_sub_modalidad)||' es de  '||v_val_tasa;
             return v_mensaje;
          else
             v_mensaje:= 'OK';
             return v_mensaje;
          end if;
     exception
        when others then
           v_mensaje := 'Monto Credito supera el techo para el Sub.Tipo '|| fug_obt_des_submodalidad(6,p_cod_modalidad,p_cod_sub_modalidad);
           return v_mensaje;
     end;
  end if;
exception
  when others then
     v_mensaje := 'Error:'||sqlerrm;
     return v_mensaje;
end;

-- valida que el destino del credito sea el permitido para este tipo de solicitud

FUNCTION fu_val_destino(p_cod_modalidad in pr_solicitudes.cod_modalidad%type,
                        p_cod_sub_modalidad in pr_solicitudes.cod_sub_modalidad%type,
                        p_cod_destino in pr_solicitudes.Cod_Destino%type)
  return varchar2
IS
v_cod_des_fpy ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_DES_FOGAPY', 6, p_cod_modalidad, NULL, NULL, p_cod_sub_modalidad);
BEGIN


-- verificamos si el codigo de destino corresponde a los habilitados por la fogapy
  if instr(v_cod_des_fpy, p_cod_destino) = 0 then
        return 'ERROR. El destino de credito seleccionado no corresponde a este tipo de credito. Verifique ';
  end if;
 return 'OK';
END;
---
FUNCTION fu_val_mto_gar_cobertura(p_cod_persona in pr_solicitudes.cod_persona%type,
                                  p_cod_moneda in pr_solicitudes.cod_moneda%type,
                                  p_cod_modalidad in pr_solicitudes.cod_modalidad%type,
                                  p_cod_sub_modalidad in pr_solicitudes.cod_sub_modalidad%type,
                                  p_mto_credito pr_solicitudes.monto%type,
                                  p_mto_garantia pr_garantias.mto_aplicado%type)
return varchar2
IS
v_cod_tas_fpy ge_tasas.cod_Tasa%type := fug_obt_pardinamico('COD_TAS_COB_FOGAPY', 6, p_cod_modalidad, null, null, p_cod_sub_modalidad);
v_val_tas_cob_fpy pr_sol_cargos.val_tasa%type;
v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(6);
v_fec_vigencia date;
v_tip_valor    ge_tasas.tip_valor%type;
v_tipo         ge_tasas.tipo%type;

BEGIN
	-- obtiene la tasa de cobertura de fogapy
  pag_gen.pr_obt_val_tasa(6,
                             p_cod_modalidad,
                             null, /*p_cod_oficina*/
                             NULL /*cuenta*/,
                             p_cod_moneda,
                             p_mto_garantia /*monto*/,
                             'S' /*tasa es personalizada*/,
                             v_cod_tas_fpy,
                             NULL/*transac*/,
                             v_fec_actual,
                             v_val_tas_cob_fpy,
                             v_fec_vigencia,
                             v_tip_valor,
                             v_tipo,
                             p_cod_persona,
                             p_cod_sub_modalidad);



	--v_val_tas_cob_fpy := OBTENER_VALOR_DE_TASA_FIJA(v_cod_tas_fpy, v_fec_actual);

    if nvl(v_val_tas_cob_fpy,0) > 0 then
      -- si el monto aplicado en la garantia es superior al tope maximo configurado en la tasa (250) para la cobertura de
      -- garantia, debe emitir un mensaje de error.
      if nvl(p_mto_garantia,0) > (nvl(p_mto_credito,0) * v_val_tas_cob_fpy/100) then
         return 'ERROR. El monto '||p_mto_garantia||' aplicado a la garantia FOGAPY no debe superar el '||v_val_tas_cob_fpy||'% del total del credito';
      else
         return 'OK';
      end if;
    else
       return 'ERROR. No se pudo recuperar el valor de la tasa '||v_cod_tas_fpy||' Valor: '||v_val_tas_cob_fpy;
    end if;

END;

--- calcula los cargos mensuales que afectaria la cuota
--
FUNCTION fu_obt_mto_car_mensual (p_nro_solicitud         pr_solicitudes.nro_solicitud%TYPE,
                                 p_nro_cuota              pr_sol_cuotas.nro_cuota%type,
                                 p_val_tas_comision       pr_sol_cargos.val_tasa%type,
                                 p_tipo                   varchar2)
RETURN NUMBER
IS
  v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
  v_tip_valor         ge_tasas.tip_valor%type;
  v_tipo              ge_tasas.tipo%type;
  v_fec_actual        date := pag_cal.FU_OBT_FEC_ACTUAL(6);
  v_cod_mon_local			ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_redondeo number(2) :=0;
  v_mto_cargo         pr_sol_cargos.monto%type;
  v_cod_tas_fpy ge_tasas.cod_Tasa%type;
  v_val_tas_cob_fpy ge_tas_fechas.val_tasa%type;--valor de la tasa de cobertura de fogapy
  v_sal_Capital pr_sol_cuotas.sal_cap_anterior%type;
  v_dias            pr_sol_cuotas.dia_periodo%type;
  rg_soli pr_solicitudes%rowtype;
  rg_sim pr_simulaciones%rowtype;
 -- v_cod_mod_che_roga ge_par_dinamicos.val_parametro%Type := nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA'),668);
   v_cod_mod_che_roga      ge_par_dinamicos.val_parametro%type;
  v_fog_cuo_des_dos_ano ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('FOG_CUO_DES_DOS_ANO');
  v_fog_cuo_has_dos_ano ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('FOG_CUO_HAS_DOS_ANO');
  v_fog_cuo_des_tre_ano ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('FOG_CUO_DES_TRE_ANO');
  v_fog_cuo_has_tre_ano ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('FOG_CUO_HAS_TRE_ANO');
  v_por_cob_gar_50 number;
  v_por_cob_gar_30 number;
  v_por_apl_com_fog ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('POR_APL_COM_FOG');  
  v_cod_sexo ba_per_fisicas.cod_sexo%type;

BEGIN
  v_por_cob_gar_50 := to_number(nvl(fug_obt_pardinamico('POR_COB_GAR_50',v_cod_mod_che_roga),0.5)); --80
  v_por_cob_gar_30 := to_number(nvl(fug_obt_pardinamico('POR_COB_GAR_30',v_cod_mod_che_roga),0.3)); --50
  -- si viene desde la propuesta
  if p_tipo ='PRO' then
      BEGIN
       SELECT *
         INTO rg_soli
         FROM pr_solicitudes
       WHERE nro_solicitud = p_nro_solicitud;
     EXCEPTION
       WHEN OTHERS THEN
         return 0;
     END;
     --
     if rg_soli.cod_moneda <> v_cod_mon_local then
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', rg_soli.cod_modulo, rg_soli.cod_modalidad, rg_soli.cod_moneda, rg_soli.cod_oficina, rg_soli.cod_sub_modalidad);
     end if;
     v_cod_mod_che_roga:= nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA', rg_soli.cod_modulo,rg_soli.cod_modalidad),'N'); 
     -- obtiene la tasa de cobertura de fogapy
     v_cod_tas_fpy := fug_obt_pardinamico('COD_TAS_COB_FOGAPY',rg_soli.cod_modulo, rg_soli.cod_modalidad, rg_soli.cod_moneda, rg_soli.cod_oficina, rg_soli.cod_sub_modalidad);
     -- diferentes condiciones para CHE ROGA
    -- if rg_soli.cod_modalidad = v_cod_mod_che_roga then
    if v_cod_mod_che_roga = 'S' then
       begin
         select sal_cap_anterior, dia_periodo
           into v_sal_capital, v_dias
           from pr_sol_cuotas
          where nro_solicitud = p_nro_solicitud
            and nro_cuota = p_nro_cuota;
       exception
         when no_data_found then
           return 0;
       end;
     else
    --- obtiene valor de tasa de cobertura
     pag_gen.pr_obt_val_tasa(rg_soli.cod_modulo, rg_soli.cod_modalidad,
                             null, null, rg_soli.cod_moneda,
                               null /*monto*/, 'S', v_cod_tas_fpy, null, --transaccion
                               v_fec_actual, v_val_tas_cob_fpy, v_fec_vigencia, v_tip_valor, v_tipo,rg_soli.cod_persona, rg_soli.cod_sub_modalidad);

      begin
        select sal_cap_anterior, dia_periodo
          into v_sal_capital, v_dias
          from pr_sol_cuotas
         where nro_solicitud = p_nro_solicitud
           and nro_cuota = p_nro_cuota + 1;
      exception
        when no_data_found then
          return 0;
      end;
     end if;
	begin
      select COD_SEXO
        into v_cod_sexo 	  
	    from ba_per_fisicas p , pr_solicitudes s
	   where 1=1
		 and s.cod_persona = p.cod_persona
		 and s.nro_solicitud = p_nro_solicitud;
      exception 
      when others then
      v_cod_sexo := 'M';
      end;
	  if upper(v_cod_sexo) = 'F' then 
	  v_por_apl_com_fog := v_por_apl_com_fog * 0.5;
	  end if;
       --dbms_output.put_line('v_cod_mod_che_roga: '||v_cod_mod_che_roga || ' rg_soli.cod_modalidad: '||rg_soli.cod_modalidad);
         --dbms_output.put_line('Cuo: '||p_nro_cuota || ' Capital: '||v_sal_Capital||' periodo: '||v_dias );
        if (p_nro_cuota between v_fog_cuo_des_dos_ano and v_fog_cuo_has_dos_ano and v_cod_mod_che_roga = 'S') then
            v_sal_capital := v_sal_capital * v_por_cob_gar_50; --80
            v_mto_cargo :=  round(((v_sal_capital * v_por_apl_com_fog /100) / 12 /** 1.10*/) ,v_redondeo); -- sin iva incluido porque en el cobro le sumaremos
        elsif (p_nro_cuota between v_fog_cuo_des_tre_ano and v_fog_cuo_has_tre_ano and v_cod_mod_che_roga = 'S') then
            v_sal_capital := v_sal_capital * v_por_cob_gar_30; -- 50
            v_mto_cargo :=  round(((v_sal_capital * v_por_apl_com_fog /100) / 12 /** 1.10*/) ,v_redondeo);
        else
            v_mto_cargo :=  round(((v_sal_capital* v_val_tas_cob_fpy/100) * p_val_tas_comision * v_dias / 36500) ,v_redondeo);
        end if;
        
        RETURN v_mto_cargo;
             --
  end if;

  --- si viene de la simulacion
  if p_tipo ='SIM' then
     BEGIN
       SELECT *
         INTO rg_sim
         FROM pr_simulaciones
       WHERE nro_simulacion = p_nro_solicitud;
     EXCEPTION
       WHEN OTHERS THEN
         return 0;
     END;
     --
     if rg_sim.cod_moneda <> v_cod_mon_local then
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', rg_sim.cod_modulo, rg_sim.cod_modalidad, rg_sim.cod_moneda, null, rg_sim.cod_sub_modalidad);
     end if;
     -- obtiene la tasa de cobertura de fogapy
     v_cod_tas_fpy := fug_obt_pardinamico('COD_TAS_COB_FOGAPY',rg_sim.cod_modulo, rg_sim.cod_modalidad, rg_sim.cod_moneda,null, rg_sim.cod_sub_modalidad);

    --- obtiene valor de tasa de Cobertura
     pag_gen.pr_obt_val_tasa(rg_sim.cod_modulo, rg_sim.cod_modalidad,
                             null, null, rg_sim.cod_moneda,
                               null /*monto*/, 'S', v_cod_tas_fpy, NULL, --Transaccion
                               v_fec_actual, v_val_tas_cob_fpy, v_fec_vigencia, v_tip_valor, v_tipo,rg_sim.cod_persona, rg_sim.cod_sub_modalidad);


      begin
          select sal_anterior, per_dias
            into v_sal_Capital, v_dias
            from pr_sim_cuotas
          where nro_simulacion = p_nro_solicitud
           and nro_cuota = p_nro_cuota + 1;
         exception
         when no_data_found then
             return 0;
         end;

         --dbms_output.put_line('Cuo: '||p_nro_cuota || ' Capital: '||v_sal_Capital||' periodo: '||v_dias );

        v_mto_cargo :=  ROUND(((v_sal_Capital* v_val_tas_cob_fpy/100) * p_val_tas_comision * v_dias / 36500) ,v_redondeo);

        RETURN v_mto_cargo;
  end if;


EXCEPTION
when others then
  raise_application_error(-20001,'Error al calcular cargo Fogapy '||sqlerrm);
END;

end pap_fpy;
/
