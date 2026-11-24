CREATE OR REPLACE PROCEDURE IT.prt_act_sol_empresas
                            (RP_TSOLIC      in TA_SOLICITUDES%ROWTYPE default null,
                             p_nro_cuenta   in ta_cta_tarjetas.nro_cuenta%type   default null, 
                             p_tip_alta     in varchar2,
                             p_can_error    in out number) IS

-----------------------------------------------------------------------------------------------------------
---DE-2011 - Nuevo proceso de alta Masiva de Tarjetas de Crédito para Tarjetas Empresariales. DYD-SDSL-3133
---LCabrera - Julio/2016
---Objetivo: controlar datos importados para adicionales de tarjetas empresariales -----------------------
-------------registrar las solicitudes de TC si corresponde según instrucción recibida en parámetros   ----
-----------------------------------------------------------------------------------------------------------

 
 v_nro_solicitud     ta_solicitudes.nro_solicitud%type;
 v_can_errores       number;
 v_can_adi_tmp       number;
 v_can_sol_principal number;
 v_can_sol_adicional number;
 v_nro_cta_tarjeta   ta_cta_tarjetas.nro_cuenta%type;
 v_can_error         number;
 
procedure lp_ver_archivo(p_nro_solicitud  ta_solicitudes.nro_solicitud%type,
                         p_can_error      in out number) is


cursor c_datos is
  select dat.*, dat.rowid fila
    from ta_sol_apr_empresas_tmp dat
   where nvl(generado,'N') = 'N';
   
rg_ta_sol_apr      ta_sol_apr_empresas_tmp%ROWTYPE;
v_tip_persona      ba_personas.tipo%TYPE;
v_error            ta_sol_apr_empresas_tmp.det_error%TYPE;
v_mto_linea        number;
v_mto_solicitado   number;

PRAGMA AUTONOMOUS_TRANSACTION;

begin  


-----------------------------------------------------------------------------------------------------------
---Antes de verificar otros errores se verifica que el monto solicitado no supere a linea de TC principal--
-----------------------------------------------------------------------------------------------------------
      --VACIO ERRORES ANTERIORES
      update ta_sol_apr_empresas_tmp ar
         set ar.nro_cta_tarjeta = p_nro_cuenta
       where nvl(GENERADO,'N') = 'N';
       COMMIT;      
      
      update ta_sol_apr_empresas_tmp ar
         set ar.det_error = NULL
       where (p_nro_solicitud is not null and
             ar.nro_solicitud = p_nro_solicitud)
          or (p_nro_cuenta is not null and
             ar.nro_cta_tarjeta = p_nro_cuenta)
         AND nvl(GENERADO,'N') = 'N';
       COMMIT;

   begin
     select mto_linea
       into v_mto_linea
       from (select u.monto mto_linea
               from ta_solicitudes u
              where (p_nro_solicitud is not null and
                    u.nro_solicitud = p_nro_solicitud)
             union
             select tar.lin_credito mto_linea
               from ta_cta_tarjetas tar
              where (p_nro_cuenta is not null and
                    tar.nro_cuenta = p_nro_cuenta));
   exception
     when others then
       v_mto_linea := 0;
   end;
   
   
  begin
     select sum(ar.monto)
       into v_mto_solicitado
       from ta_sol_apr_empresas_tmp ar
      where (p_nro_solicitud is not null
             and
             ar.nro_solicitud = p_nro_solicitud)
             or  (p_nro_cuenta is not null 
                   and
                   ar.nro_cta_tarjeta = p_nro_cuenta);
   exception
     when others then
       v_mto_solicitado := 0;
   end;

   if nvl(v_mto_solicitado,0) > nvl(v_mto_linea,0) then

      update ta_sol_apr_empresas_tmp ar
         set ar.det_error = 'Monto Solicitado Supera Línea de Tarjeta Principal'
       where (p_nro_solicitud is not null and
             ar.nro_solicitud = p_nro_solicitud)
          or (p_nro_cuenta is not null and
             ar.nro_cta_tarjeta = p_nro_cuenta);
       COMMIT;
   end if;

 For c IN c_datos Loop
   v_error := null;
---------------------------------------------------------------------------------------------
                          ---Realizar controles en Archivo--
---------------------------------------------------------------------------------------------
       BEGIN
         SELECT p.cod_persona, p.tipo
           INTO rg_ta_sol_apr.cod_persona,
                v_tip_persona
           FROM ba_personas p
          WHERE p.nro_documento = c.nro_documento;
       EXCEPTION
         WHEN no_data_found THEN
           v_error := nvl(v_error, '') || '#' ||
                      'No existe Persona con este documento';
           GOTO siguiente_registro;
         WHEN too_many_rows THEN
           v_error := nvl(v_error, '') || '#' ||
                      'Mas de una Persona con este documento';
           GOTO siguiente_registro;
         WHEN OTHERS THEN
           v_error := nvl(v_error, '') || '#' ||
                      'Error al traer codigo de Persona para el documento : ' ||
                      rg_ta_sol_apr.nro_documento || ' Error : ' || SQLERRM;
           GOTO siguiente_registro;
       END;
      If length(c.nom_embozado) > 20 then
         v_error := nvl(v_error, '') || '#' ||
                      'Nombre Embozado supera los 20 caracteres : ' ||
                      rg_ta_sol_apr.nro_documento;        
      End if;

      --
      UPDATE ta_sol_apr_empresas_tmp p
         SET p.cod_persona = rg_ta_sol_apr.cod_persona,
             p.det_error = v_error
       WHERE p.rowid = c.fila;  
       COMMIT;   
       
      -- Verificar si es persona física 
      IF v_tip_persona <> 'F' THEN
         v_error := nvl(v_error, '') || '#' || 'Persona no es Física';
         GOTO siguiente_registro;
      END IF;     


      <<siguiente_registro>>
      -- Si no hubo error debe actualizar a nulo si es reproceso
      UPDATE ta_sol_apr_empresas_tmp l
         SET det_error = v_error
       WHERE l.rowid = c.fila;
       COMMIT;

       select count(*)
         into v_can_error
         from ta_sol_apr_empresas_tmp
        where det_error is not null;

       p_can_error := nvl(v_can_error,0);

   End Loop;
   
end lp_ver_archivo;

--Función Interna para recuperar Nuevo nro. de Solicitud
FUNCTION LF_OBT_NRO_SOLICITUD return varchar IS

  v_nro_solicitud ta_solicitudes.nro_solicitud%type;
begin
  begin
    ---Obtener Nro. de Secuencia
    Select S_NRO_SOLICITUD.NEXTVAL into v_nro_solicitud from dual;
  
  exception
    when others then
      raise_application_error(-20001,
                              'PRT_ACT_SOL_EMPRESAS: No se pudo Obtener Nro. de Solicitud.');
  end;
  return v_nro_solicitud;

END;

----Proceso Interno --- Inserción Solicitud Principal
PROCEDURE LP_INS_SOL_PRINCIPAL(p_nro_solicitud in out ta_solicitudes.nro_solicitud%type,
                               RP_TSOLIC       in     ta_solicitudes%ROWTYPE,
                               P_CAN_SOL_ADICIONAL IN NUMBER) IS

BEGIN
    -----Insertar Solicitud
    begin
      insert into ta_solicitudes
        (nro_solicitud,
         cod_persona,
         cod_oficina,
         cod_modulo,
         cod_modalidad,
         cod_usu_promotor,
         fec_solicitud,
         cod_usu_oficial,
         fec_aprobacion,
         cod_causa,
         deb_automatico,
         nro_cta_debito,
         tip_cobro,
         nom_embozado,
         lin_sugerida,
         monto,
         puntaje,
         cod_estado,
         cod_est_sugerido,
         tas_int_adelanto,
         tas_financiacion,
         tas_mora,
         mto_min_pago,
         por_pag_minimo,
         tip_envio,
         referencia,
         usu_insercion,
         fec_insercion,
         usu_modificacion,
         fec_modificacion,
         nro_linea,
         observacion,
         cod_moneda,
         cod_campana,
         cod_canal,
         mto_aprobado,
         niv_aprobacion,
         nro_acta,
         nro_cuenta,
         afinidad,
         sub_afinidad,
         pre_embozada,
         ind_evaluacion,
         cod_tip_cierre,
         cod_rub_economico,
         tip_plastico,
         tas_int_corriente,
         tas_int_compra,
         por_vip,
         mto_fij_pag_minimo,
         mto_min_pag_minimo,
         tas_int_mora )
      values
        (p_nro_solicitud,
         RP_TSOLIC.cod_persona,
         RP_TSOLIC.cod_oficina,
         RP_TSOLIC.cod_modulo,
         RP_TSOLIC.cod_modalidad,
         RP_TSOLIC.cod_usu_promotor,
         nvl(RP_TSOLIC.fec_solicitud,trunc(sysdate)),
         RP_TSOLIC.cod_usu_oficial,
         RP_TSOLIC.fec_aprobacion,
         RP_TSOLIC.cod_causa,
         RP_TSOLIC.deb_automatico,
         RP_TSOLIC.nro_cta_debito,
         RP_TSOLIC.tip_cobro,
         RP_TSOLIC.nom_embozado,
         RP_TSOLIC.lin_sugerida,
         RP_TSOLIC.monto,
         RP_TSOLIC.puntaje,
         'APR', --RP_TSOLIC.cod_estado,
         RP_TSOLIC.cod_est_sugerido,
         RP_TSOLIC.tas_int_adelanto,
         RP_TSOLIC.tas_financiacion,
         RP_TSOLIC.tas_mora,
         RP_TSOLIC.mto_min_pago,
         RP_TSOLIC.por_pag_minimo,
         RP_TSOLIC.tip_envio,
         RP_TSOLIC.referencia,
         RP_TSOLIC.usu_insercion,
         RP_TSOLIC.fec_insercion,
         RP_TSOLIC.usu_modificacion,
         RP_TSOLIC.fec_modificacion,
         RP_TSOLIC.nro_linea,
         RP_TSOLIC.observacion,
         RP_TSOLIC.cod_moneda,
         RP_TSOLIC.cod_campana,
         RP_TSOLIC.cod_canal,
         RP_TSOLIC.monto, ---se asigna mismo monto ingresado por pantalla
         RP_TSOLIC.niv_aprobacion,
         RP_TSOLIC.nro_acta,
         RP_TSOLIC.nro_cuenta,
         RP_TSOLIC.afinidad,
         RP_TSOLIC.sub_afinidad,
         RP_TSOLIC.pre_embozada,
         RP_TSOLIC.ind_evaluacion,
         RP_TSOLIC.cod_tip_cierre,
         RP_TSOLIC.cod_rub_economico,
         RP_TSOLIC.tip_plastico,
         RP_TSOLIC.tas_int_corriente,
         RP_TSOLIC.tas_int_compra,
         RP_TSOLIC.por_vip,
         RP_TSOLIC.mto_fij_pag_minimo,
         RP_TSOLIC.mto_min_pag_minimo,
         RP_TSOLIC.tas_int_mora);
    exception 
      when others then 
          raise_application_error(-20001,'Al Insertar Solicitud de TC.'||sqlerrm);
    end;
  
  begin
      insert into ta_sol_garantias t
        (nro_solicitud, cod_garantia, mto_aplicado)
      values
        (p_nro_solicitud, 1, RP_TSOLIC.monto);
    exception
      when others then
        raise_application_error(-20001,'Al Insertar Garantia de Solicitud de TC.'||sqlerrm);
    end;


   begin
     update ta_sol_apr_empresas_tmp g
        set g.nro_solicitud = p_nro_solicitud
      where g.nro_solicitud is null
        and rownum < P_CAN_SOL_ADICIONAL +1;

   exception
     when others then
       raise_application_error(-20005,'LP_INS_SOL_PRINCIPAL error al Actualizar 
                                       datos en ta_sol_apr_empresas_tmp. ' ||sqlerrm);
   end;
   p_nro_solicitud := v_nro_solicitud;

END;

----Proceso interno - Inserción de Solicitudes Adicionales
PROCEDURE LP_INS_SOL_ADICIONAL (P_NRO_SOLICITUD    TA_SOLICITUDES.NRO_SOLICITUD%TYPE DEFAULT NULL,
                                P_NRO_CTA_TARJETA  TA_CTA_TARJETAS.NRO_CUENTA%TYPE DEFAULT NULL) IS

cursor ta_sol (P_NRO_SOLICITUD    TA_SOLICITUDES.NRO_SOLICITUD%TYPE default null,
               P_NRO_CTA_TARJETA  TA_CTA_TARJETAS.NRO_CUENTA%TYPE default null)is
  select tmp.cod_persona cod_cli_adicional,
         tmp.nro_documento,
         cta.cod_oficina,
         cta.cod_modulo,
         cta.tip_cobro,
         cta.cod_modalidad,
         cta.cod_usu_promotor,
         trunc(sysdate) fec_solicitud,
         cta.cod_usu_promotor cod_usu_oficial,
         trunc(sysdate) fec_apertura,
         cta.tas_adelanto,
         cta.cod_causa,
         cta.deb_automatico,
         cta.nro_cta_debito,
         cta.por_pag_minimo,
         TMP.NOM_EMBOZADO,
         cta.lin_credito,
         'APR' cod_estado,
         cta.cod_moneda,
         cta.tas_financiacion,
         cta.tas_mora,
         cta.mto_min_pago,
         cta.cod_canal,
         NULL tip_envio,
         null referencia,
         cta.nro_linea,
         cta.nro_cuenta,
         null nro_solicitud,
         cta.cod_campana, 
         g.cod_persona cod_cli_principal
    from ta_sol_apr_empresas_tmp tmp, ta_cta_tarjetas cta,
         ge_cta_clientes g
   where tmp.nro_cta_tarjeta = cta.nro_cuenta
     and cta.nro_cuenta = g.nro_cuenta
     and cta.cod_modulo = g.cod_modulo
     and cta.cod_modalidad = g.cod_modalidad
     and g.relacion = 'P'
     and (p_nro_cuenta is not null and cta.nro_cuenta = p_nro_cuenta)
     and tmp.det_error is null
     and nvl(tmp.generado,'N') = 'N'
     and tmp.cod_persona is not null
  union
  select tmp.cod_persona cod_cli_adicional,
         tmp.nro_documento,
         cta.cod_oficina,
         cta.cod_modulo,
         cta.tip_cobro,
         cta.cod_modalidad,
         cta.cod_usu_promotor,
         trunc(sysdate) fec_solicitud,
         cta.cod_usu_oficial,
         trunc(sysdate) fec_apertura,
         null tas_adelanto,
         cta.cod_causa,
         cta.deb_automatico,
         cta.nro_cta_debito,
         cta.por_pag_minimo,
         tmp.nom_embozado,
         tmp.monto,
         'APR' cod_estado,
         cta.cod_moneda,
         cta.tas_financiacion,
         cta.tas_mora,
         cta.mto_min_pago,
         cta.cod_canal,
         cta.tip_envio,
         cta.referencia referencia,
         cta.nro_linea,
         null nro_cuenta,
         cta.nro_solicitud,
         cta.cod_campana, 
         cta.cod_persona cod_cli_principal
    from ta_sol_apr_empresas_tmp tmp, ta_solicitudes cta
   where tmp.nro_solicitud = cta.nro_solicitud
     and (p_nro_solicitud is not null and cta.nro_solicitud = p_nro_solicitud)
     and tmp.det_error is null
     and nvl(tmp.generado,'N') = 'N'
     and tmp.cod_persona is not null;

v_exi_vinculo varchar2(1);

begin

    for t in ta_sol(P_NRO_SOLICITUD, P_NRO_CTA_TARJETA ) loop
        --Inserta Adicionales por una sola Cuenta / Solicitud ---------------------
        begin
           insert into ta_sol_adicionales
                  (nro_solicitud   , cod_persona     , cod_estado   , fec_aprobacion  ,
                   fec_ingreso     , cod_causa       , nom_embozado , cod_usu_autoriza,
                   cod_usu_promotor, cod_usu_oficial , observacion, nro_cuenta )
            values (t.nro_solicitud, t.cod_cli_adicional   , t.cod_estado  , t.fec_apertura,
                    sysdate, t.cod_causa, t.nom_embozado  , null  ,
                    t.cod_usu_promotor,  t.cod_usu_oficial , 'Alta Masiva Tarjeta Empresariales',t.nro_cuenta );
         exception
           when others then
             raise_application_error(-20004,'Ocurrio un error al insertar datos en TA_SOL_ADICIONALES Doc.Nro.'||t.nro_documento||' '||sqlerrm);
         end; 


        begin
          update ta_sol_apr_empresas_tmp g
             set g.generado = 'S'
           where g.nro_documento = t.nro_documento
             and (g.nro_solicitud = t.nro_solicitud
                 or g.nro_cta_tarjeta = t.nro_cuenta)
             and g.det_error is null;
        exception
          when others then
             raise_application_error(-20005,'Ocurrió un error al Actualizar datos en ta_sol_apr_empresas_tmp '||sqlerrm);
        end;
        begin
          select 'E'
            into v_exi_vinculo
            from ba_vinculos g
           where g.cod_per_vinculo = t.cod_cli_adicional
             and g.cod_persona = t.cod_cli_principal;
         exception
           when  no_data_found then
             insert into ba_vinculos (cod_persona, cod_per_vinculo, tipo)
                   values (t.cod_cli_principal, t.cod_cli_adicional, 'OT');
           when others then
             null; --- DYD-SDSL-3416 09/09/2016
            ---- raise_application_error(-20005,'Ocurrió un error al Actualizar vinculo '||sqlerrm);
          end;
       end loop;
end;       

-----------------------------------------------------------------------------------------
---------------INICIO DE PROCESO PRINCIPAL-----------------------------------------------
-----------------------------------------------------------------------------------------
begin
  If p_tip_alta = 'E' and p_nro_cuenta is null  then
    raise_application_error(-20004,'PRT_ACT_SOL_EMPRESAS: No se recibió Nro. Cuenta.');
  Elsif p_tip_alta = 'E' and p_nro_cuenta is not null then
    v_nro_cta_tarjeta := p_nro_cuenta;
  End if;

  ---Verificar datos de adicionales importados
  lp_ver_archivo(v_nro_solicitud, v_can_errores);

If nvl(v_can_errores,0) < 1 then ---Procesar solo si no hay errores
  Select nvl(count(*), 0)
    into v_can_adi_tmp
  from ta_sol_apr_empresas_tmp;  
  
  --Si hay registros que procesar 
  If v_can_adi_tmp > 0 then
    --Si es Alta (N) Se debe crear una Solicitud(Principal) y N-Varios (Adicionales)
    If p_tip_alta = 'N'  then
       --Si es Alta (N) Se debe crear una Solicitud(Principal) y N-Varios (Adicionales)
       v_can_sol_principal := 1;
       v_can_sol_adicional := v_can_adi_tmp;
       
    Elsif  p_tip_alta = 'E'  then
       --Si es Alta (E) NO se debe crear Solicitud(Principal) y Si se crea N-Varios (Adicionales)
       v_can_sol_principal := 0;
       v_can_sol_adicional := v_can_adi_tmp;
       
    Elsif p_tip_alta = 'M'  then
      --Si es Alta (M) Se debe crear Varias Solicitudes(Principales) y N-Varios (Adicionales)
       v_can_sol_principal := v_can_adi_tmp;
       v_can_sol_adicional := v_can_adi_tmp;

    End if;
  End if;


   --Si es Alta (N) Se debe crear una Solicitud(Principal) y N-Varios (Adicionales)
    If p_tip_alta = 'N'  then
       --Si es Alta (N) Se debe crear una Solicitud(Principal) y N-Varios (Adicionales)
       FOR P in 1..v_can_sol_principal LOOP 
    
        v_nro_solicitud := LF_OBT_NRO_SOLICITUD;
        lp_ins_sol_principal(v_nro_solicitud, RP_TSOLIC, v_can_sol_adicional);
        lp_ins_sol_adicional(v_nro_solicitud, v_nro_cta_tarjeta);
       END LOOP;
       
    Elsif  p_tip_alta = 'E'  then
       --Si es Alta (E) NO se debe crear Solicitud(Principal) y Si se crea N-Varios (Adicionales)
          FOR AD in 1..v_can_sol_adicional LOOP
              lp_ins_sol_adicional(v_nro_solicitud, v_nro_cta_tarjeta);
          END LOOP;
      
    Elsif p_tip_alta = 'M'  then
      --Si es Alta (M) Se debe crear Varias Solicitudes(Principales) y N-Varios (Adicionales)
       --Si es Alta (N) Se debe crear una Solicitud(Principal) y N-Varios (Adicionales)
       FOR P in 1..v_can_sol_principal LOOP 
          v_nro_solicitud := LF_OBT_NRO_SOLICITUD;
          lp_ins_sol_principal(v_nro_solicitud, RP_TSOLIC, 1);
          lp_ins_sol_adicional(v_nro_solicitud, v_nro_cta_tarjeta);
       END LOOP;
    End if;

   
  End if; 
  
    select nvl(count(*), 0)
    into v_can_error
    from ta_sol_apr_empresas_tmp dat
   where det_error is not null;   
   
   p_can_error := v_can_error;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Al actualizar sol. pre-aprobadas Empresas:' || SQLERRM);
END prt_act_sol_empresas;
/

