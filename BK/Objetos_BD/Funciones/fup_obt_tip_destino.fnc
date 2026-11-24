CREATE OR REPLACE FUNCTION IT.FUP_OBT_TIP_DESTINO
(p_cod_persona ba_personas.cod_persona%type,
 p_cod_modalidad pr_cta_prestamos.cod_modalidad%type,
 p_cod_moneda pr_cta_prestamos.cod_moneda%type,
 p_mto_capital pr_cta_prestamos.mto_capital%type,
 p_mto_interes pr_cta_prestamos.sal_interes%type,
 p_mto_solicitado pr_cta_prestamos.monto%type,
 p_plazo number,
 p_tip_prestamo pr_cta_prestamos.tipo%type default 'A',
 p_res_1_actual in varchar2 default 'S') return varchar2 is
   --- Variable para retorno
   v_tip_destino pr_cta_prestamos.tip_destino%type;
   --- Variables axiliares
   v_sal_minimo pr_parametros.sal_min_vigente%type;
   v_min_exigido pr_parametros.cap_min_exigido%type;
   v_mto_solicitado pr_cta_prestamos.monto%type;
   v_cod_mon_local pr_cta_prestamos.cod_moneda%type;
   v_aux ge_cotizaciones.val_conversion%type;
   v_es_fisica varchar2(01);
begin
   select nvl(sal_min_vigente,0), nvl(round(cap_min_exigido*(por_cap_min_exigido/100),0),0)
     into v_sal_minimo, v_min_exigido
     from pr_parametros;
   v_es_fisica := pag_gen.FU_ES_PER_FISICA(p_cod_persona);
   if v_es_fisica = 'O' then
      v_es_fisica := 'S';
   end if;
   --- Convertir monto solicitado a moneda local para igualar a parametros
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   pag_gen.PR_CON_MON_A_MONEDA(p_cod_moneda, v_cod_mon_local,
      p_mto_solicitado, v_mto_solicitado, v_aux, v_aux);
   --- Valor por defecto si no entra en ningun if
   v_tip_destino := 4; --- Consumo
   --- Calcular tipo destino en base al monto solicitado
   if v_mto_solicitado <= v_sal_minimo * 5 then
      if p_res_1_actual = 'S' then
         if p_cod_modalidad not in (FUG_OBT_PARDINAMICO('CHEQUES DEVUELTOS',6),
            FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6), 62, 630) -- desc. documen y cheques post-datados
         and p_tip_prestamo = 'A' then --- Amortizable
            if v_es_fisica = 'S' then
               v_tip_destino := 4; --- Consumo
            else
               v_tip_destino := 2; --- Pequeños Deudores
            end if;
         else --- Descuento Doc. o Plazo Fijo
            v_tip_destino := 2; --- Pequeños Deudores
         end if;
      else --- Resolucion 8 - 2007
         if p_cod_modalidad not in (FUG_OBT_PARDINAMICO('CHEQUES DEVUELTOS',6),
            FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6), 62, 630) -- desc. documen y cheques post-datados
         and p_tip_prestamo = 'A' then --- Amortizable
            v_tip_destino := 5; --- Microcredito SOLO PARA RESOLUCION 8 - 2007
         else --- Descuento Doc. o Plazo Fijo
            v_tip_destino := 2; --- Pequeños Deudores
         end if;
      end if;
   elsif  v_mto_solicitado > v_sal_minimo * 5
      and v_mto_solicitado <= v_sal_minimo * 100 then
      if p_cod_modalidad not in (FUG_OBT_PARDINAMICO('CHEQUES DEVUELTOS',6),
         FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6), 62, 630) -- desc. documen y cheques post-datados
      and p_tip_prestamo = 'A' then --- Amortizable
         if v_es_fisica = 'S' then
            v_tip_destino := 4; --- Consumo
         else
            v_tip_destino := 2; --- Pequeños Deudores
         end if;
      else --- Descuento Doc. o Plazo Fijo
         v_tip_destino := 2; --- Pequeños Deudores
      end if;
   elsif  v_mto_solicitado > v_sal_minimo * 100
      and v_mto_solicitado <= v_min_exigido then
      v_tip_destino := 2; --- Pequeños Deudores
   elsif  v_mto_solicitado > v_min_exigido then --4% del Min.Exig.
      v_tip_destino := 1; --- Grandes Deudores
   end if;
   -- Vivienda -- BBVANOR-90
   if (nvl(fug_obt_pardinamico('MAD_HIPOTECARIOS',6,p_cod_modalidad), 'N') = 'S' 
     or nvl(fug_obt_pardinamico('PRE_MAD_CONSTRUCCIONES',6,p_cod_modalidad), 'N') = 'S') then
      v_tip_destino := 3; 
   end if;
   return v_tip_destino;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Parametros generales de préstamos no definidos');
end FUP_OBT_TIP_DESTINO;
/

