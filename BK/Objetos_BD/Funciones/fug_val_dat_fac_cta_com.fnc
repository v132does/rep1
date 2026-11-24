create or replace function it.fug_val_dat_fac_cta_com
 (p_cod_persona in varchar2) return varchar2 is
  v_plz_vig_facturacion ge_cam_obl_segmentacion.plz_vigencia%type := fug_obt_pardinamico('CRM_PLZ_FACTURACION');
  v_fec_plz_vigencia    date;
  v_fec_actual          ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_anho                cr_per_dat_segmentacion.ano_facturacion%type;
  v_mes                 cr_per_dat_segmentacion.mes_facturacion%type;
  v_mto_facturacion     cr_per_dat_segmentacion.mto_facturacion%type := 0;
  v_mto_min_facturacion cr_per_dat_segmentacion.mto_facturacion%type := 0;
  v_mto_max_facturacion cr_per_dat_segmentacion.mto_facturacion%type := 0;
  v_estado		          cr_per_dat_segmentacion.estado%type;
  v_cod_act_primaria    ba_personas.cod_rub_primario%type;
  v_control             NUMBER := 0;
  v_mensaje             varchar2(4000);
  v_tip_persona         ba_personas.tipo%type;
  v_ind_pro_per_fisica  varchar2(1);
begin
  --Obtengo la actividad principal del cliente.
  BEGIN
     SELECT a.cod_rub_primario, tipo
       INTO v_cod_act_primaria, v_tip_persona
       FROM ba_personas a
      WHERE a.cod_persona = p_cod_persona;
  EXCEPTION
    WHEN OTHERS THEN
      v_mensaje := 'No se encuentra la actividad primaria del Cliente.';
  END;
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
         v_mensaje := 'No se encuentran los datos de la facturación.(Opción:Carpeta de la Persona/Pestaña:Facturación)';
     end;
  end if;
  if v_mensaje is null then
    if nvl(v_estado, 'N') = 'V' then
       SELECT add_months(to_date(v_mes||'/'||v_anho,'mm/yyyy'),v_plz_vig_facturacion +1)
         into v_fec_plz_vigencia
         from dual;

       SELECT COUNT(1)
         INTO v_control
         FROM dual
        WHERE v_fec_actual >= v_fec_plz_vigencia;

       IF v_control > 0 THEN
          v_mensaje := 'El plazo de vigente del Importe de Facturación declarado por la Persona se encuentra vencida (Opción:Carpeta de la Persona/Pestaña:Facturación).';
       END IF;
    else
      v_mensaje := 'Los Datos de Facturación registrados en la carpeta de la Persona no fueron verificados (Opción:Carpeta de la Persona/Pestaña:Facturación).';
    end if;
  end if;

  if v_mensaje is null then
     if v_tip_persona = 'F' then
        begin
          select 'S'
            into v_ind_pro_per_fisica
            from ba_per_fisicas p
           where cod_persona = p_cod_persona
             and exists (select 1
                           from ba_cod_referencias
                          where dominio = 'COD_PRO_FIS_CTA_COM'
                            and val_minimo = p.cod_profesion);
        exception
          when others then
             v_ind_pro_per_fisica := 'N';
        end;
     end if;
     
     if nvl(v_ind_pro_per_fisica, 'N') = 'S' then
       begin
         select val_minimo, val_maximo
           into v_mto_min_facturacion, v_mto_max_facturacion
           from ba_cod_referencias
          where dominio = 'CCO_MTO_FAC_FIS';
       exception
         when others then
            v_mto_min_facturacion := 250000000;
            v_mto_max_facturacion := 12000000000;
       end;
     else
       begin
         select val_minimo, val_maximo
           into v_mto_min_facturacion, v_mto_max_facturacion
           from ba_cod_referencias
          where dominio = 'CCO_MTO_FAC_JUR';
        exception
          when others then
            v_mto_min_facturacion := 500000000;
            v_mto_max_facturacion := 12000000000;
        end;
      end if;
      if v_mto_facturacion < v_mto_min_facturacion then
        v_mensaje := 'No cubre el monto de facturación. (Opción:Carpeta de la Persona/Pestaña:Facturación).';
      end if;
   end if;
   return nvl(v_mensaje, 'OK');
exception
   when others then
     return 0;
end fug_val_dat_fac_cta_com;
/

