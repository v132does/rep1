CREATE OR REPLACE PACKAGE BODY IT.PAG_RBA is

/**Generar JSON**/
--Rutina Local--
/*
  --Tipo consulta como parámetro-- recibe lista_codigo, retorna texto JSON
  --Cclient: Código de cliente (código interno del banco).
  --Identificación: Identificación fiscal del cliente (persona física o jurídica).
  --Denominación: Nombre y Apellidos (persona física) o razón social (persona jurídica) del cliente.
**/
  function fu_obt_datos(p_tipo varchar2, p_criterios clob) return clob is
    v_result clob;
    v_linea clob;
    v_sql varchar2(4000);
    v_criterio varchar2(200);
    vCClient varchar2(200);
    vIdentificacion varchar2(200);
    vDenominacion varchar2(200);
    v_can_criterios number;
    tipo_incorrecto exception;
    no_criterios exception;
    can_criterios exception;
    v_can_max constant number := 50000;
  begin
    DBMS_LOB.CREATETEMPORARY(v_linea,false);
    DBMS_LOB.OPEN(v_linea,DBMS_LOB.LOB_READWRITE);
    if p_criterios is not null then
      --v_linea := replace(replace(DBMS_LOB.substr(p_criterios,DBMS_LOB.getlength(p_criterios),1),chr(10),chr(32)),chr(32),'');
      DBMS_LOB.append(v_linea,p_criterios);
    else
      raise no_criterios;
    end if;
    DBMS_LOB.CREATETEMPORARY(v_result,false);
    DBMS_LOB.OPEN(v_result,DBMS_LOB.LOB_READWRITE);
    --Abrir corchete
    DBMS_LOB.append(v_result,'['||chr(10));
    --Tipo A: ConsultaCodigo
    if p_tipo = 'A' then
      while v_linea is not null loop
        v_can_criterios := nvl(v_can_criterios,0)+1;
        if v_can_criterios > v_can_max then
          raise can_criterios;
        end if;
        if instr(v_linea,',')!=0 then
          v_criterio := ltrim(rtrim(substr(v_linea,1,instr(v_linea,',')-1)));
        else
          v_criterio := ltrim(rtrim(v_linea));
        end if;
        v_sql := 'select a.cod_persona CClient, a.nro_documento Identificacion, a.nom_completo Denominacion '||chr(10)||
                 'from ba_personas a '||chr(10)||
                 'where a.cod_persona  = '||''''||v_criterio||'''';
        begin
          execute Immediate v_sql
          into vCClient, vIdentificacion, vDenominacion;
          vDenominacion := replace(vDenominacion,'"',chr(32)); --' '
        exception
          when no_data_found then
            vCClient := v_criterio;
            vIdentificacion := 'null';
            vDenominacion := 'null';
          when too_many_rows then
            vCClient := v_criterio;
            vIdentificacion := 'null';
            vDenominacion := 'null';
        end;

        if v_can_criterios != 1 then
          DBMS_LOB.append(v_result,','||chr(10));
        end if;
        DBMS_LOB.append(v_result,'{'||chr(10));
        DBMS_LOB.append(v_result,'"cclient":'||'"'||substr(vCClient,1,200)||'"'||','||chr(10));
        DBMS_LOB.append(v_result,'"identificacion":'||'"'||substr(vIdentificacion,1,200)||'"'||','||chr(10));
        DBMS_LOB.append(v_result,'"denominacion":'||'"'||substr(vDenominacion,1,200)||'"'||chr(10));
        DBMS_LOB.append(v_result,'}');
        v_linea := substr(v_linea,length(substr(v_linea,1,instr(v_linea,',')))+1,length(v_linea));
      end loop;
    --Tipo B: ConsultaIdentificacion
    elsif p_tipo = 'B' then
      while v_linea is not null loop
        v_can_criterios := nvl(v_can_criterios,0)+1;
        if v_can_criterios > v_can_max then
          raise can_criterios;
        end if;
        if instr(v_linea,',')!=0 then
          v_criterio := ltrim(rtrim(substr(v_linea,1,instr(v_linea,',')-1)));
        else
          v_criterio := ltrim(rtrim(v_linea));
        end if;
        v_sql := 'select a.cod_persona CClient, a.nro_documento Identificacion, a.nom_completo Denominacion '||chr(10)||
                 'from ba_personas a '||chr(10)||
                 'where a.nro_documento  = '||''''||v_criterio||'''';
        begin
          execute Immediate v_sql
          into vCClient, vIdentificacion, vDenominacion;
        exception
          when no_data_found then
            vCClient := 'null';
            vIdentificacion := v_criterio;
            vDenominacion := 'null';
          when too_many_rows then
            vCClient := 'null';
            vIdentificacion := v_criterio;
            vDenominacion := 'null';
        end;
        if v_can_criterios != 1 then
          DBMS_LOB.append(v_result,','||chr(10));
        end if;
        DBMS_LOB.append(v_result,'{'||chr(10));
        DBMS_LOB.append(v_result,'"cclient":'||'"'||substr(vCClient,1,200)||'"'||','||chr(10));
        DBMS_LOB.append(v_result,'"identificacion":'||'"'||substr(vIdentificacion,1,200)||'"'||','||chr(10));
        DBMS_LOB.append(v_result,'"denominacion":'||'"'||substr(vDenominacion,1,200)||'"'||chr(10));
        DBMS_LOB.append(v_result,'}');
        v_linea := substr(v_linea,length(substr(v_linea,1,instr(v_linea,',')))+1,length(v_linea));
      end loop;
    else
      raise tipo_incorrecto;
    end if;
    --Cerrar corchete
    DBMS_LOB.append(v_result,chr(10));
    DBMS_LOB.append(v_result,']'||chr(10));

    return v_result;
  exception
    when no_criterios then
      raise_application_error(-20000, 'No se ha recibido ningún Criterio.');
    when can_criterios then
      raise_application_error(-20000, 'Se ha superado la cantidad máxima de Criterios que se puede procesar!');
    when tipo_incorrecto then
      raise_application_error(-20000, 'El Tipo de Consulta recibido como parámetro es incorrecto. Debe ser A o B');
    when others then
      raise_application_error(-20000,sqlerrm);
  end fu_obt_datos;
--Rutina Local--
/**Generar JSON**/


  --Función que establece la fecha de datos o de proceso--
  function fu_set_fec_datos(p_fec_datos date default null) return date is
    v_fec_datos date;
  begin
    if p_fec_datos is not null then
      v_fec_datos := pag_cal.fu_obt_fec_habil(last_day(p_fec_datos),-1,2);
      --Si se ingresa una fecha mayor al ultimo dia habil del mes
      --Se pone la fecha al ultimo dia habil del mes
      if p_fec_datos > v_fec_datos then
        v_fec_datos := v_fec_datos;
      else --sino se setea a la fecha ingresada--
        v_fec_datos := p_fec_datos;
      end if;
    else
      v_fec_datos := pag_cal.fu_obt_fec_actual(1);
    end if;
    return v_fec_datos;
  end fu_set_fec_datos;


  function fu_wsi_kyc_datos(p_cod_persona in ba_personas.cod_persona%type)
  return typ_kycdatos is

   v_regDatos            typ_kycdatos := typ_kycdatos();
   v_regPersonas         ba_personas%rowtype;
   v_regPerFisicas       ba_per_fisicas%rowtype;
   v_regPerJuridicas     ba_per_juridicas%rowtype;
   v_regLaborales        cr_inf_laborales%rowtype;
   v_regSegmentacion     cr_per_dat_segmentacion%rowtype;
   v_regaccPortador      ba_acc_portador%rowtype;
   v_regactesperadas     cr_act_esperadas%rowtype;
   v_cod_pai_residencia  ba_direcciones.cod_pais%type;
   v_dir_principal       ba_direcciones.direccion%type;
   v_cod_ofi_cliente     ge_clientes.cod_oficina%type;
   v_usu_oficial         ge_clientes.cod_usu_oficial%type;
   v_ofi_gestor          ba_usuarios.cod_oficina%type;
   v_indpep              cr_inf_fondos.pep%type;
   v_seg_actividad       varchar2(200);
   v_ind_accportador     varchar2(1) default 'N';
   v_can_vínculos        number;
   v_vinculos            varchar2(200);
   v_url_crm             varchar2(200);
   v_tip_iva             varchar2(200);
   v_est_civil           varchar2(200);
   v_tip_empleo          varchar2(200);
   v_tip_act_inter       varchar2(200);

   function fp_des_ramo(p_cod_ramo ba_ramos.cod_ramo%type)
     return varchar2 is
     v_des_ramo ba_ramos.descripcion%type;
   begin
     select descripcion
       into v_des_ramo
       from ba_ramos
      where cod_ramo = p_cod_ramo;
     return v_des_ramo;
   exception
     when no_data_found then
       return null;
     when others then
       return null;
   end;

  BEGIN
    -- Registro de Personas
    begin
      select * into v_regPersonas
        from ba_personas
       where cod_persona = p_cod_persona;
       v_regDatos.error := 'N';
    exception
      when no_data_found then
        v_regDatos.error := 'S';
        v_regDatos.mensaje := 'Persona '||p_cod_persona||' Inexistente';
    end;
    -- País de Residencia y Dirección Principal
    begin
      select a.cod_pais
        into v_cod_pai_residencia
        from ba_direcciones a
       where a.cod_persona = p_cod_persona
         and a.principal = 'S';
    exception
      when no_data_found then
        v_cod_pai_residencia := null;
    end;
    v_dir_principal := fue_obt_dat_personas(p_cod_persona,'DIR');
    -- Oficina del Cliente y Gestor
    begin
      select a.cod_oficina, a.cod_usu_oficial
        into v_cod_ofi_cliente, v_usu_oficial
        from ge_clientes a
       where a.cod_persona = p_cod_persona;
    exception
      when no_data_found then
        v_cod_ofi_cliente := null;
        v_usu_oficial := null;
    end;
    if v_usu_oficial is not null then
      -- Oficina del Gestor.
      begin
        select a.cod_oficina
          into v_ofi_gestor
          from ba_usuarios a
         where a.cod_usuario = v_usu_oficial
           and a.oficial = 'S';
      end;
    end if;
    -- Registro Laborales
    begin
      select * into v_regLaborales
        from cr_inf_laborales
       where cod_persona = p_cod_persona
         and actual = 'S'
         and rownum = 1;
    exception
      when no_data_found then null;
    end;
    -- Registro de Segmentación
    begin
      select * into v_regSegmentacion
        from cr_per_dat_segmentacion
       where cod_persona = p_cod_persona;
    exception
      when no_data_found then null;
    end;
    -- Registro de Acciones al Portador
    begin
      select * into v_regaccPortador
        from ba_acc_portador
       where cod_persona = p_cod_persona;
    exception
      when no_data_found then null;
    end;
    if v_regaccPortador.Cod_Persona is not null then
      v_ind_accportador := 'S';
    end if;
    -- Vínculos
    begin
      select count(1)
        into v_can_vínculos
        from ba_vinculos a
       where a.cod_persona = p_cod_persona;
    exception
      when no_data_found then
        v_can_vínculos := null;
    end;
    if nvl(v_can_vínculos,0) > 1 then
      v_vinculos := v_can_vínculos||' Personas Vínculadas.';
    end if;
    -- Segmento Actividad
    begin
      select '('||a.val_parametro||') '||b.significado
        into v_seg_actividad
        from ba_per_dat_adicionales a, ba_cod_referencias b
       where a.cod_persona = p_cod_persona
         and a.parametro = 'DTM_RIESGO'
         and b.dominio = a.parametro
         and b.val_minimo = a.val_parametro;
    exception
      when no_data_found then null;
    end;
    -- Actividades Esperadas
    begin
      select * into v_regactesperadas
        from cr_act_esperadas a
       where a.cod_persona = p_cod_persona
         and a.fecha = (select max(b.fecha)
                          from cr_act_esperadas b
                         where b.cod_persona = a.cod_persona);
    exception
      when no_data_found then null;
    end;
    -- Url Crm
    begin
      select distinct a.url_crm into v_url_crm
        from ge_per_pro_control a
       where a.cod_persona = p_cod_persona
         and a.fecha = (select max(b.fecha)
                          from ge_per_pro_control b
                         where b.cod_persona = a.cod_persona);
    exception
      when no_data_found then null;
    end;

    if v_regPersonas.Tipo = 'F' then
      -- Registro de Personas Físicas
      begin
        select * into v_regPerFisicas
          from ba_per_fisicas
         where cod_persona = p_cod_persona;
      end;
      -- Indicador Pep
      begin
        select pep into v_indpep
          from cr_inf_fondos
         where cod_persona = p_cod_persona;
      end;
    else
      -- Registro de Personas Jurídicas
      begin
        select * into v_regPerJuridicas
          from ba_per_juridicas
         where cod_persona = p_cod_persona;
      end;
    end if;
    v_tip_iva := fue_obt_des_refcodes('TIP_IVA',v_regPersonas.Tip_Iva);
    if v_tip_iva like 'Referencia%no%reg%' then
      v_tip_iva := null;
    end if;

    v_est_civil := fue_obt_des_refcodes('COD_EST_CIVIL',v_regPerFisicas.Est_Civil);
    if v_est_civil like 'Referencia%no%reg%' then
      v_est_civil := null;
    end if;

    v_tip_empleo := fue_obt_des_refcodes('TIP_EMPLEO',v_regLaborales.Tip_Empleo);
    if v_tip_empleo like 'Referencia%no%reg%' then
      v_tip_empleo := null;
    end if;

    v_tip_act_inter := fue_obt_des_refcodes('TIP_ACT_INTERNACIONAL',v_regPerJuridicas.Tip_Act_Internacional);
    if v_tip_act_inter like 'Referencia%no%reg%' then
      v_tip_act_inter := null;
    end if;

    v_regDatos.tipoDocumento            := fue_obt_tip_doc_abreviatura(v_regPersonas.Cod_Tip_Documento);
    v_regDatos.fechaNacimiento          := to_char(v_regPerFisicas.Fec_Nacimiento,'dd/mm/yyyy');
    v_regDatos.paisOrigen               := fue_obt_des_pais(v_regPersonas.Cod_Pais);
    v_regDatos.PaisResidencia           := fue_obt_des_pais(v_cod_pai_residencia);
    v_regDatos.tipIva                   := v_tip_iva;
    v_regDatos.fechaAlta                := to_char(trunc(v_regPersonas.Fec_Insercion),'dd/mm/yyyy');
    v_regDatos.oficinaCliente           := fue_obt_des_oficina(v_cod_ofi_cliente);
    v_regDatos.oficinaGestor            := fue_obt_des_oficina(v_ofi_gestor);
    v_regDatos.actividadPrimaria        := '('||v_regPersonas.Cod_Rub_Primario||') '||fug_obt_des_actividad(v_regPersonas.Cod_Rub_Primario, 'N');
    v_regDatos.estadoCivil              := v_est_civil;
    v_regDatos.ocupacion                := fue_obt_des_profesion(v_regPerFisicas.Cod_Profesion);
    v_regDatos.direccionPrincipal       := v_dir_principal;
    v_regDatos.lugarTrabajo             := v_regLaborales.Lug_Trabajo;
    v_regDatos.mtoIngreso               := trim(to_char(v_regLaborales.Mto_Ingreso,'999G999G999G999D99'));
    v_regDatos.situacionLaboral         := v_tip_empleo;
    v_regDatos.vinculos                 := v_vinculos;
    v_regDatos.anhoFacturacion          := v_regSegmentacion.Ano_Facturacion;
    v_regDatos.mtoFacturacion           := trim(to_char(v_regSegmentacion.Mto_Facturacion,'999G999G999G999D99'));
    v_regDatos.monAccionesPortador      := v_regaccPortador.Cod_Moneda;
    v_regDatos.canTransaccionesDebito   := v_regactesperadas.can_tra_debito;
    v_regDatos.canTransaccionesCredito  := v_regactesperadas.can_tra_credito;
    v_regDatos.mtoPromedioDebito        := trim(to_char(v_regactesperadas.mto_pro_debito,'999G999G999G999D99'));
    v_regDatos.mtoPromedioCredito       := trim(to_char(v_regactesperadas.mto_pro_credito,'999G999G999G999D99'));
    v_regDatos.fecActividaddesEsperadas := to_char(trunc(v_regactesperadas.fecha),'dd/mm/yyyy');
    v_regDatos.indPep                   := v_indpep;
    v_regDatos.segmentoActividad        := v_seg_actividad;
    v_regDatos.capitalOperativo         := trim(to_char(v_regPerJuridicas.Cap_Operativo,'999G999G999G999D99'));
    v_regDatos.razonComercial           := v_regPerJuridicas.Nom_Comercial;
    v_regDatos.ramo                     := fp_des_ramo(v_regPerJuridicas.Cod_Ramo);
    v_regDatos.fechaConstitucion        := to_char(trunc(v_regPerJuridicas.Fec_Apertura),'dd/mm/yyyy');
    v_regDatos.importaExporta           := v_tip_act_inter;
    v_regDatos.cantidadEmpleados        := v_regPerJuridicas.Can_Empleados;
    v_regDatos.cantidadSocios           := v_regPerJuridicas.Can_Socios;
    v_regDatos.cantidadSucursales       := v_regPerJuridicas.Can_Sucursales;
    v_regDatos.accionesAlPortador       := v_ind_accportador;
    v_regDatos.capitalSuscrito          := trim(to_char(v_regaccPortador.Cap_Suscrito,'999G999G999G999D99'));
    v_regDatos.capitalIntegrado         := trim(to_char(v_regaccPortador.Cap_Integrado,'999G999G999G999D99'));
    v_regDatos.canAccionesPortador      := v_regaccPortador.Can_Acc_Portador;
    v_regDatos.urlCrm                   := 'URL:'||v_url_crm;
    

    RETURN v_regDatos;


  EXCEPTION
     WHEN OTHERS THEN
       v_regDatos.error := 'S';
       v_regDatos.mensaje := 'Ocurrió un Error.';
       RETURN v_regdatos;
  END;

  --Funcion que Inhibe o Deshinibe al Cliente
  function fu_act_inhibidos(p_cod_persona in varchar2,
                            p_cod_proceso varchar2,
                            p_tip_proceso varchar2,
                            p_tipo varchar2 default 'I')
    /* Valores posibles para p_tipo;
    I = Ingresa a Proceso de Control en RBA (llamado desde rbaonline)
    F = RBA finaliza el WF de Proceso de Control, se invoca online o desde batch contingente.
    */
    /* Retorna
    0-->Procesado Corréctamente
    1-->Cliente no existente
    2--> Otro error
    */
    return number is
    v_inhibidas       varchar2(1) := 'N';
    v_existe          varchar2(1) := 'N';
    v_cod_cau_inicio  varchar2(10) default fug_obt_pardinamico('COD_CAU_INI_PRO_CONTROL');
    v_cod_cau_fin     varchar2(10) default fug_obt_pardinamico('COD_CAU_FIN_PRO_CONTROL');
    v_tex_detalle     varchar2(2000) default fug_obt_pardinamico('TEX_DET_INHIBICION');
    v_fec_actual      date default pag_cal.fu_obt_fec_actual(1);
    v_fec_vencimiento date;
    v_nro_orden       number default 1;
    v_return          number default 0;
    v_tip_pro_local   varchar2(1);
    function fu_obt_nro_orden return number is
    begin
      begin
        select nvl(max(nro_orden),0) + 1
          into v_nro_orden
          from ge_per_inhibidas
         where cod_persona = p_cod_persona;
      exception
        when no_data_found then
          v_nro_orden := 1;
      end;
      return nvl(v_nro_orden,1);
    end;
    function fu_lev_inhibicion return boolean is
      v_existe varchar2(1) := 'N';
    begin
      select distinct 'S' into v_existe
        from ge_per_pro_control a
       where a.cod_persona = p_cod_persona
         and a.cod_pro_control != p_cod_proceso
         and a.estado = 'P';
       if v_existe = 'S' then
         return false;
       else
         return true;
       end if;
    exception
      when no_data_found then
        return true;
    end;
    procedure pr_log_programa(p_det_error varchar2) is
      pragma autonomous_transaction;
    begin
      insert into ge_log_errores(cod_programa, campo1, dato1, campo2, dato2, campo3, dato3, det_error)
      values ('pag_rba.fu_act_inhibidos','p_cod_persona',p_cod_persona,'p_cod_proceso',p_cod_proceso,'p_tip_proceso#p_tipo',p_tip_proceso||'#'||p_tipo, p_det_error);
      commit;
    end;
    --
  begin
    Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
    pr_log_programa('Inicio de ejecución'); 
    if p_tip_proceso is not null then
      if p_tip_proceso = '0' then
        v_tip_pro_local := 'A';
      elsif p_tip_proceso = '2' then
        v_tip_pro_local := 'R';
      end if;
    end if;
    begin
      select 'S'
        into v_existe
        from ge_clientes
       where cod_persona = p_cod_persona;
    exception
      when no_data_found then
        v_return := 1;
        pr_log_programa('Persona Inexistente '||sqlerrm); 
        goto fin;
    end;
    if v_existe = 'S' then
      if p_tipo = 'I' then
        v_nro_orden := fu_obt_nro_orden;
        v_fec_vencimiento := v_fec_actual + fug_obt_parcausales(v_cod_cau_inicio,'PLA_INHABILITACION');
        begin
          insert into ge_per_inhibidas
            (cod_persona, nro_orden, cod_causa, fec_inicio, fec_vencimiento,
             origen, referencia, detalle, estado, situacion)
          values
            (p_cod_persona, v_nro_orden, v_cod_cau_inicio, v_fec_actual, v_fec_vencimiento,
             'RBA-KYC', 'Ini. Proc. Control', v_tex_detalle, 'I', 'P' );
        exception
          when others then
            v_return := 2;
            pr_log_programa('Error al insertar en ge_per_inhibidas '||sqlerrm); 
        end;
      elsif p_tipo = 'F' then
        -- Actualiza estado del proceso de control
        begin
          update ge_per_pro_control a
             set a.estado = v_tip_pro_local
           where a.cod_persona = p_cod_persona
             and a.cod_pro_control = p_cod_proceso
             and a.estado = 'P';
        exception
          when others then
          v_return := 2;
          pr_log_programa('Error al actualizar ge_per_pro_control '||sqlerrm); 
        end;
        --
        if p_tip_proceso = '0' then -- Autorizado
          if fu_lev_inhibicion then -- verifica si ya puede levantar inhibición.
            begin
              select 'S'
                into v_inhibidas
                from ge_per_inhibidas a
               where a.cod_persona = p_cod_persona
                 and a.estado = 'I'
                 and a.origen = 'RBA-KYC';
            exception
              when no_data_found then
                v_return := 2;
                pr_log_programa('No se encontró ninguna Inhibición '||sqlerrm); 
            end;
            -- Se levanta la Inhibición.
            if v_inhibidas = 'S' then
              begin
                update ge_per_inhibidas a
                   set a.estado = 'D',
                       a.cod_rehabilitacion = '007'
                 where a.cod_persona = p_cod_persona
                   and a.estado = 'I'
                   and a.origen = 'RBA-KYC'
                   and a.nro_orden = (select max(b.nro_orden)
                                        from ge_per_inhibidas b
                                       where b.cod_persona = a.cod_persona
                                         and b.origen = a.origen);
              exception
                when others then
                v_return := 2;
                pr_log_programa('Error al intentar levantar la Inhibición cod_rehabilitacion = 007 '||sqlerrm); 
              end;
            end if;
          end if;
        else --p_tip_proceso = '2' then -- No Autorizado
          -- Se finaliza la Inhibición de Inicio de proc. control
          begin
            update ge_per_inhibidas a
               set a.estado = 'D',
                   a.cod_rehabilitacion = '008'
             where a.cod_persona = p_cod_persona
               and a.nro_orden = (select max(b.nro_orden)
                                    from ge_per_inhibidas b
                                   where b.cod_persona = a.cod_persona
                                     and b.origen = 'RBA-KYC');
          exception
            when others then
            v_return := 2;
            pr_log_programa('Error al intentar levantar la Inhibición cod_rehabilitacion = 008 '||sqlerrm); 
          end;
          -- Nueva Inhibición por Vinculación denegada.
          v_nro_orden := fu_obt_nro_orden;
          begin
            insert into ge_per_inhibidas
             (cod_persona, nro_orden, cod_causa, fec_inicio, fec_vencimiento,
              origen, referencia, detalle, estado, situacion)
            values
             (p_cod_persona, v_nro_orden, v_cod_cau_fin, v_fec_actual, v_fec_vencimiento,
             'RBA-KYC', 'Vin. Denegada PC', null, 'I', 'P' );
          exception
            when others then
            v_return := 2;
            pr_log_programa('Error al insertar Inhibición por Vin. Denegada. '||sqlerrm); 
          end;
        end if;
      end if;
    end if;
    <<fin>>
    return v_return;
  end;

  --Funcion para obtener la fecha de datos o de proceso--
  function fu_obt_fec_datos return date is
    v_fec_datos date;
  begin
    v_fec_datos := pag_rba.g_fec_datos;
    return v_fec_datos;
  end fu_obt_fec_datos;

  -- Procedimiento de insercion de LOG --
  procedure pr_log_rba(rp_glrba ge_log_rba%rowtype) is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; end;
    insert into ge_log_rba(fecha,nom_referencia,mensaje)
    values(rp_glrba.fecha,rp_glrba.nom_referencia,rp_glrba.mensaje);
    commit;
  end pr_log_rba;

  -- Procedimiento de insercion de Datos de Clientes --
  procedure pr_dat_clientes(rp_sdc smg_dat_clientes%rowtype) is
  begin
    insert into smg_dat_clientes(cod_cliente,puntaje,des_puntaje,riesgo,raa,pep)
    values(rp_sdc.cod_cliente,rp_sdc.puntaje,rp_sdc.des_puntaje,rp_sdc.riesgo,rp_sdc.raa,rp_sdc.pep);
  end pr_dat_clientes;

  -- Actualización de Datos de Clientes RBA --
  procedure pr_act_rba_dat_cliente( p_fec_datos date default null ) is
    c_nom_proceso   varchar2(100) := 'PAG_RBA.PR_ACT_RBA_DAT_CLIENTE';
    v_directorio    varchar2(1000) := fug_obt_pardinamico('DIR_ARC_RBA');
    v_archivo       utl_file.file_type;
    v_linea         varchar2(32767);
    v_msj           varchar2(4000);
    rp_sdc          smg_dat_clientes%rowtype;
    v_can_registros number;
    v_hora_ini      date;
  begin
    v_hora_ini := sysdate;
    pag_rba.g_fec_datos := pag_rba.fu_set_fec_datos(p_fec_datos);
    pag_rba.g_ult_dia_mes_habil := pag_cal.fu_obt_fec_habil(last_day(pag_rba.g_fec_datos),-1,2);
    pag_rba.g_archivo := 'RBA_DATA_'||to_char(trunc(pag_rba.g_fec_datos),'YYYYMMDD')||'.dat';
    pag_rba.g_lugar := 'Procesando Archivo '||pag_rba.g_archivo;
    -- abrir archivo
    if utl_file.is_open(v_archivo) = FALSE then
      v_archivo := utl_file.fopen(v_directorio, pag_rba.g_archivo , 'R');
    end if;
    sql_util.ejecute_dml('TRUNCATE TABLE SMG_DAT_CLIENTES ', v_msj);
    IF v_msj IS NOT NULL THEN
      raise_application_error(-20000,c_nom_proceso||' - '||sqlerrm);
    END IF;
    loop
      begin
        utl_file.get_line(v_archivo, v_linea);
        v_can_registros := nvl(v_can_registros,0) + 1;
        rp_sdc.cod_cliente := rtrim(ltrim(substr(v_linea,1,9)));
        rp_sdc.riesgo := rtrim(ltrim(substr(v_linea,10,1)));
        if rp_sdc.riesgo = 'A' then
          rp_sdc.des_puntaje := 'ALTO';
        elsif rp_sdc.riesgo = 'B' then
          rp_sdc.des_puntaje := 'BAJO';
        elsif rp_sdc.riesgo = 'M' then
          rp_sdc.des_puntaje := 'MEDIO';
        end if;
        rp_sdc.raa := rtrim(ltrim(substr(v_linea,11,1)));
        rp_sdc.pep := rtrim(ltrim(substr(v_linea,12,1)));
        pag_rba.pr_dat_clientes(rp_sdc);
      exception
          when no_data_found then
            exit;
      end;
    end loop;
    -- cerrar archivo
    if utl_file.is_open(v_archivo) = TRUE then
       utl_file.fclose(v_archivo);
    end if;
    --Generar LOG--
    pag_rba.rp_glrba.fecha          := pag_rba.g_fec_datos;
    pag_rba.rp_glrba.nom_referencia := 'RBA_DATA';
    pag_rba.rp_glrba.mensaje        := 'FINALIZADO : '||nvl(v_can_registros,0)||' registros procesados. '||chr(10)||
                                       'Hora Inicio : '||to_char(v_hora_ini,'HH24:MI:SS')||'.'||chr(10)||
                                       'Hora Fin : '||to_char(sysdate,'HH24:MI:SS')||'.';
    pag_rba.pr_log_rba(pag_rba.rp_glrba);
  exception
    when no_data_found then
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    when utl_file.invalid_path then
      utl_file.fclose(v_archivo);
      raise_application_error(-20000,'Directorio inválido');
    when utl_file.invalid_mode then
      utl_file.fclose(v_archivo);
      raise_application_error(-20000,'Modo invalido');
    when utl_file.invalid_filehandle then
      utl_file.fclose(v_archivo);
      raise_application_error(-20000,'Invalida Filehandle');
    when utl_file.invalid_operation then
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    when utl_file.read_error then
      utl_file.fclose(v_archivo);
      raise_application_error(-20000,'Error de Lectura');
    when utl_file.write_error then
      utl_file.fclose(v_archivo);
      raise_application_error(-20000,'Error de Escritura');
    when utl_file.internal_error then
      utl_file.fclose(v_archivo);
      raise_application_error(-20000,'Error interno');
    when others then
      --Generar LOG--
      pag_rba.rp_glrba.fecha          := trunc(sysdate);
      pag_rba.rp_glrba.nom_referencia := 'RBA_DATA';
      pag_rba.rp_glrba.mensaje        := 'ERROR : '||substr(sqlerrm,1,800)||'.'||chr(10)||
                                         'Hora Inicio : '||to_char(v_hora_ini,'HH24:MI:SS')||'.'||chr(10)||
                                         'Hora Fin : '||to_char(sysdate,'HH24:MI:SS')||'.';
      pag_rba.pr_log_rba(pag_rba.rp_glrba);
      if sqlcode <= -20000 then
        raise;
      else
        raise_application_error(-20000,pag_rba.g_lugar||' - '||sqlerrm);
      end if;
  END pr_act_rba_dat_cliente;

  -- Procesamiento del Archivo de Bloqueos Masivos RBA --
  procedure pr_pro_blo_masivos is
    v_directorio    varchar2(1000) := fug_obt_pardinamico('DIR_ARC_RBA');
    v_fec_actual    date := pag_cal.fu_obt_fec_actual(1);
    v_nom_archivo   varchar2(60) := 'BLOQUEO_MASIVO_'||to_char(trunc(v_fec_actual),'YYYYMMDD')||'.txt';
    v_archivo       utl_file.file_type;
    v_linea         varchar2(32767);
    v_fec_archivo   varchar2(8);
    rg_blmtmp       ge_blo_masivos_tmp%rowtype;
    v_can_registros number;
    v_hora_ini      timestamp;
    v_cadprc varchar2(60);
    v_prcdep varchar2(60);
    v_lonprc number;
    v_codprc varchar2(2);
    v_inhibir number(1);
    cursor c_dat is
    select * from ge_blo_masivos_tmp;
    procedure pr_ins_blo_masivos_tmp(rg_bl ge_blo_masivos_tmp%rowtype) is
    begin
      insert into ge_blo_masivos_tmp(fecha, cod_persona, linea)
      values (rg_bl.fecha, rg_bl.cod_persona, rg_bl.linea);
    end;
  begin
    v_hora_ini := current_timestamp;
    -- Leer Archivo BLOQUEO_MASIVO_YYYYMMDD.txt
    if utl_file.is_open(v_archivo) = FALSE then
      v_archivo := utl_file.fopen(v_directorio, v_nom_archivo , 'R');
    end if;
    delete ge_blo_masivos_tmp;
    loop
      begin
        utl_file.get_line(v_archivo, v_linea);
        v_can_registros := nvl(v_can_registros,0) + 1;
        v_fec_archivo   := rtrim(ltrim(substr(v_linea,1,8)));
        rg_blmtmp.fecha := to_date(v_fec_archivo,'YYYYMMDD');
        rg_blmtmp.cod_persona := rtrim(ltrim(substr(v_linea,9,9)));
        rg_blmtmp.linea := substr(v_linea,1,37);

        pr_ins_blo_masivos_tmp(rg_blmtmp);
      exception
          when no_data_found then
            exit;
      end;
    end loop;
    -- cerrar archivo
    if utl_file.is_open(v_archivo) = TRUE then
       utl_file.fclose(v_archivo);
    end if;
    --Generar LOG--
    pag_rba.rp_glrba.fecha          := pag_rba.g_fec_datos;
    pag_rba.rp_glrba.nom_referencia := 'RBA_BLO_MASIVO';
    pag_rba.rp_glrba.mensaje        := 'FINALIZADO : '||nvl(v_can_registros,0)||' registros procesados. '||chr(10)||
                                       'Hora Inicio : '||to_char(v_hora_ini,'HH24:MI:SS:FF')||'.'||chr(10)||
                                       'Hora Fin : '||to_char(current_timestamp,'HH24:MI:SS:FF')||'.';
    pag_rba.pr_log_rba(pag_rba.rp_glrba);

    -- Proceso de datos
    insert into ge_blo_masivos(fecha, cod_persona, linea)
    select fecha, cod_persona, linea from ge_blo_masivos_tmp;
    --
    for k in c_dat loop
      v_cadprc := substr(k.linea,18,20);
      v_prcdep := trim(v_cadprc);
      v_lonprc := length(v_prcdep);
      for i in 1.. 10 loop
        v_codprc := substr(v_prcdep,1,2);
        v_prcdep := substr(v_prcdep,3,length(v_prcdep));
        v_codprc := trim(v_codprc);
        if v_codprc is not null then
          begin
            insert into ge_per_pro_control
            (fecha, cod_persona, cod_pro_control, estado)
            values
            (v_fec_actual, k.cod_persona, v_codprc, 'P');
          end;
          v_inhibir := pag_rba.fu_act_inhibidos(k.cod_persona, v_codprc, 'I');
        else
          exit;
        end if;
      end loop;
    end loop;
  end pr_pro_blo_masivos;

end pag_rba;
/

