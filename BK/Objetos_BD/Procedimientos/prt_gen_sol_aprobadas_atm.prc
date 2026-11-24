CREATE OR REPLACE PROCEDURE IT.PRT_GEN_SOL_APROBADAS_ATM is
  v_afinidad      ta_sol_aprobadas_tmp.afinidad%type;
  v_sub_afinidad  ta_sol_aprobadas_tmp.sub_afinidad%type;
  v_cod_modalidad ta_sol_aprobadas_tmp.cod_modalidad%type;
  v_nro_solicitud ta_sol_aprobadas_tmp.nro_solicitud%type;
  v_cod_tip_doc   ta_sol_aprobadas_tmp.cod_tip_documento%type;
  v_error         ge_cli_aprobados_atm.det_error%type;
  v_cod_rub_economico pr_solicitudes.cod_rub_economico%type:= fug_obt_pardinamico('COD_RUB_ECO_PRE_APR_ATM',5);
  ---Flexibilidad ---
  v_denominacion_cp varchar2(100);
  v_fec_vto_campana date;
  v_existe  varchar2(1):='N';
  v_cod_modulo ta_solicitudes.cod_modulo%type := 5;
  v_count number;
  v_nro_orden number := 0; 
	cursor c_solicitudes is
  	select t.*, t.rowid fila
      from GE_CLI_APROBADOS_ATM t
     where t.acepta = 'S'
       and t.nro_solicitud is null;
  
  cursor c_rch_solicitudes is
     select t.nro_solicitud
       from GE_CLI_APROBADOS_ATM t
      where t.acepta = 'S'
        and t.nro_solicitud is not null
        and not exists (select 1 from ta_solicitudes b where t.nro_solicitud = b.nro_solicitud)
        and t.det_error is not null  --DYDMR-11642 actualizamos en esta tabla el error
        --and exists (select 1 from ta_sol_aprobadas_tmp c where t.nro_solicitud = c.nro_solicitud and c.det_error is not null);    
		    and trunc(fec_insercion) >= add_months(trunc(sysdate), -2); -- por dos meses va intentar crear la solicitud  DYDMR-11642

   
begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END; 
  for i in c_solicitudes loop
    v_error := null;
    v_nro_orden := v_nro_orden + 1;
    begin
      select substr(val_minimo, 1, 6), substr(val_minimo, 7, 2)
        into v_afinidad, v_sub_afinidad
        from ba_cod_referencias
       where dominio = 'EQU_AFINIDAD'
         and val_maximo = i.clase--i.val_maximo
         and abreviatura = i.afinidad;--i.abreviatura;
    exception
      when no_data_found then
        v_error := nvl(v_error, '') || '#' ||
                   'Afinidad SIGRIM no definida. Verificar en dominio EQU_AFINIDAD';
    end;
    
    begin
      select distinct cod_modalidad
        into v_cod_modalidad
        from ta_tipos t
       where t.afinidad = v_afinidad
         and nvl(t.sub_afinidad, '00') = nvl(v_sub_afinidad, '00');
    exception
      when no_data_found then
        v_error := nvl(v_error, '') || '#' || 'Modalidad no registrada para la afinidad ' ||
                   v_afinidad || ' sub-afinidad ' || v_sub_afinidad;
    end;
    
    begin
      select s_nro_solicitud.nextval
        into v_nro_solicitud
        from sys.dual;
    exception
      when others then
        v_error := nvl(v_error, '') || '#' || 'Error al traer secuencia de solicitudes : ' || SQLERRM;
    end;
    
    v_cod_tip_doc := fue_obt_doc_principal(i.cod_persona);
    
    if v_error is null then
      begin
        insert into ta_sol_aprobadas_tmp 
           (nro_documento, cod_tip_documento, monto, cod_oficina, cod_modalidad, 
            afinidad, nom_embozado,cod_tip_cierre, cod_persona, sub_afinidad, 
            nro_solicitud, val_minimo, val_maximo, cod_canal, cod_campana,cod_rub_economico, nro_doc_titular, tar_adicional, nro_orden)
        values
           (i.nro_documento, v_cod_tip_doc, i.lin_aprobada, i.cod_oficina, v_cod_modalidad,
            v_afinidad, i.nom_embozar, i.cod_tip_cierre, i.cod_persona, v_sub_afinidad,
            v_nro_solicitud, i.afinidad, i.clase, i.cod_canal, i.cod_campana,v_cod_rub_economico, null, 'N',v_nro_orden);
        --    
        prt_act_sol_aprobada(v_nro_solicitud);--genera la solicitud en estado APR
        -- obtengo el error generado en el procedimiento prt_act_sol_aprobada
        select det_error into v_error from ta_sol_aprobadas_tmp where nro_solicitud = v_nro_solicitud;
        --
      exception
        when no_data_found then
           null;
          --v_error := 'No se pudo obtener datos de la solicitud creada.'||v_nro_solicitud;
        when others then
          v_error := 'No se pudo crear la solicitud '|| sqlerrm;
      end;
      -- si hubo error entonces actualiza el dato 
      if v_error is not null then
        update ge_cli_aprobados_atm a
           set a.det_error = v_error,
               a.nro_solicitud = v_nro_solicitud
         where a.cod_persona = i.cod_persona
           and a.rowid = i.fila;
      else
         update ge_cli_aprobados_atm a
           set a.nro_solicitud = v_nro_solicitud,
               a.det_error = null
         where a.cod_persona = i.cod_persona
           and a.rowid = i.fila;     
      end if;     
       --********Flexibilidad en modulo Preaprobados de Consumo y TDC en el Core 03/03*********************
             begin
                select distinct 'S'
                  into v_existe
                  from GE_PRO_CAMPANAS a
                 where a.nro_solicitud=v_nro_solicitud
                  and a.cod_modulo=5;
              exception
                when others then
                  v_existe := 'N';
              end;
              --Obtenemos los datos de la campaña actual
              begin
                select a.denominacion, a.fec_vto_campana
                  into v_denominacion_cp, v_fec_vto_campana
                   from ge_pro_pre_aprobados a
                     where a.cod_campana=i.cod_campana 
                        and a.cod_persona=i.cod_persona
                         and a.estado='V'
                         and a.cod_modulo= 5
                         and a.cod_modalidad= v_cod_modalidad
                         and rownum=1;
              exception
                when others then
                   v_denominacion_cp:=null;
              end;
          if nvl(v_existe, 'N') = 'N' then
            BEGIN
              insert into GE_PRO_CAMPANAS ( nro_solicitud,
                                                   cod_persona,
                                                   cod_campana,
                                                   denominacion,
                                                   fec_vto_campana,
                                                   cod_modulo,
                                                   cod_modalidad)
                                          values ( v_nro_solicitud,
                                                   i.cod_persona,
                                                   i.cod_campana,
                                                   v_denominacion_cp,
                                                   v_fec_vto_campana,
                                                   5,
                                                   v_cod_modalidad);
            EXCEPTION
              WHEN OTHERS THEN
                raise_application_error(-20000,'No se puede insertar la inf. de campana. '||sqlerrm);
            END;
          end if;
          commit;
          /*
          ||CORETOTD-1 - Traspaso de Operativa Digital de PreAprobados TC a CPO
          ||Desarrollo CORE - 09/10/2017 - GAC
          */
          select NVL(count(0),0) into v_count from ta_sol_aprobadas_tmp where nro_solicitud = v_nro_solicitud;
          if v_count = 0 then
             PRG_GEN_CRM_LEAD(i.cod_persona, '1', i.cod_canal, v_cod_modulo, v_cod_modalidad, i.cod_campana, v_nro_solicitud, i.lin_aprobada, i.afinidad); 
          end if;										    
    else
      update ge_cli_aprobados_atm a
         set a.det_error = v_error
       where a.cod_persona = i.cod_persona
         and a.rowid = i.fila;
    end if;
    
  end loop;
  
  for i in c_rch_solicitudes loop
    prt_act_sol_aprobada(i.nro_solicitud);--genera la solicitud en estado APR para solicitudes que tuvieron errores y fueron correjidas.
  end loop;
  
end prt_gen_sol_aprobadas_atm;
/

