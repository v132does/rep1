create or replace procedure IT.PRG_GEN_ARC_COBROS(p_fecha date default null,
                                               p_tip_proceso varchar2 default 'N') is
  v_directorio   varchar2(30);
  v_archivo      UTL_FILE.FILE_TYPE;  
  v_fecha        date;
  v_hor_inicial  varchar2(8);
  v_hor_ini      varchar2(8);
  v_hor_fin      varchar2(8);
  v_procesado    varchar2(10);
  v_cont_cab     number   :=0;
  v_cont_det     number   :=0;
  v_nom_archivo  varchar2(100);
  c_limit        CONSTANT PLS_INTEGER := 10000;

  cursor entidad is 
  select t.val_minimo cod_entidad
    from ba_cod_referencias t
   where t.dominio = 'COD_ENT_COBRO';
   
  function fu_obt_tip_cobro(p_nro_cuenta varchar2, p_nro_cuota number, p_fecha date, p_hora varchar2 ) return varchar2 is
    v_existe   varchar2(10) default null;
    v_usuario  varchar2(20) :=null;
    v_cantidad number(20)   :=0;
  begin                           
     select distinct(a.cod_usuario)
      into v_usuario
      from pr_movimientos_his a
     where a.fecha = p_fecha
       and a.hora = p_hora
       and a.nro_cuenta = p_nro_cuenta
       and a.nro_documento3 = p_nro_cuota
       and a.cod_tra_padre = 359
       and a.estado='N';
       
       if v_usuario is not null then
         SELECT COUNT(*)
           INTO v_cantidad
           FROM pr_movimientos_his b
          WHERE b.fecha = p_fecha
            AND b.hora = p_hora
            AND b.cod_usuario = v_usuario
            AND b.cod_tra_padre = 358;
             
         IF v_cantidad > 0 THEN
           v_existe := 'REFI';
         END IF;
       end if;
                     
    return v_existe;
  exception
    when no_data_found then
      return null;
    when others then
      return null;
  end;

  PROCEDURE lp_act_mat_view(p_tip_proceso varchar2)
    is 
    begin 
      if nvl(p_tip_proceso,'N') = 'N' then
        -- Refrescar vista materializada
        DBMS_MVIEW.REFRESH(list => 'IT.vw_per_vinculadas', -- Nombre de la vista materializada
                           method => 'C',  -- 'C' para un refresco completo
                           atomic_refresh => FALSE -- Permite acceso durante el refresco, sin ser atómico
                           );
        DBMS_MVIEW.REFRESH(list => 'IT.vm_cta_cobranzas', -- Nombre de la vista materializada
                           method => 'C',  -- 'C' para un refresco completo
                           atomic_refresh => FALSE -- Permite acceso durante el refresco, sin ser atómico
                           );
        DBMS_MVIEW.REFRESH(list => 'IT.vm_cta_tarjetas', -- Nombre de la vista materializada
                           method => 'C',  -- 'C' para un refresco completo
                           atomic_refresh => FALSE -- Permite acceso durante el refresco, sin ser atómico
                           );                                                      
      elsif p_tip_proceso = 'T' then
        -- Refrescar vista materializada
        DBMS_MVIEW.REFRESH(list => 'IT.vw_per_vinculadas', -- Nombre de la vista materializada
                           method => 'C',  -- 'C' para un refresco completo
                           atomic_refresh => FALSE -- Permite acceso durante el refresco, sin ser atómico
                           );
        DBMS_MVIEW.REFRESH(list => 'IT.vm_cta_tarjetas', -- Nombre de la vista materializada
                           method => 'C',  -- 'C' para un refresco completo
                           atomic_refresh => FALSE -- Permite acceso durante el refresco, sin ser atómico
                           );
      end if;

    exception
      when others then 
        raise_application_error(-20000, 'Error lp_act_mat_view: '||sqlerrm);   
    end;    
  
  PROCEDURE LP_INS_LOG(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2, p_archivo varchar2, p_cont varchar2)
    is pragma autonomous_transaction;
    v_observacion varchar2(1000) := null;
   
    
    begin 
      if p_archivo is not null then
        v_observacion := p_archivo||';'||p_cont;
      end if;
           
      insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin, observacion)
      values(v_fecha,'PRG_GEN_ARC_COBROS',p_cod_proceso, p_hor_ini, p_hor_fin, v_observacion);
      commit;
    exception
      when others then null;
    end;  
    
  PROCEDURE LP_GEN_PRE_CUENTAS(p_archivo out UTL_FILE.FILE_TYPE,
                            p_directorio in varchar2,
                            p_cod_entidad in varchar2)
     IS
    v_reg_cab      varchar2(8000);
    v_arc_cab      UTL_FILE.FILE_TYPE;
    v_nom_arc_det  varchar2(30);
    v_reg_det      varchar2(8000);
    v_arc_det      UTL_FILE.FILE_TYPE;
    v_mto_iva_des  number := 0;
    v_rev_desembolso varchar2(1) := 'N';
    
    TYPE rec_cabecera IS RECORD(nro_operacion        ge_cuentas.nro_cuenta%type,
                                cod_moneda           ba_monedas.cod_moneda%type,
                                cod_modalidad        ge_cuentas.cod_modalidad%type,
                                nom_cliente          varchar2(1000),
                                ape_cliente          varchar2(1000),
                                tipo                 ba_personas.tipo%type,
                                nro_doc_cliente      ba_personas.nro_documento%type,
                                cod_tipo_doc_cliente ba_personas.cod_tip_documento%type,
                                sexo                 ba_per_fisicas.cod_sexo%type,
                                cli_confidencial     ge_clientes.cli_confidencial%type,
                                cli_especial         ge_clientes.cli_especial%type,
                                es_funcionario       varchar2(1),
                                fec_nacimiento       ba_per_fisicas.fec_nacimiento%type,
                                relacion             ge_cta_clientes.relacion%type,
                                nom_conyuge          varchar2(1000),
                                ape_conyuge          varchar2(1000),
                                nro_doc_conyuge      ba_personas.nro_documento%type,
                                cod_tip_doc_conyuge  ba_personas.cod_tip_documento%type,
                                sexo_conyuge         ba_per_fisicas.cod_sexo%type,
                                judicializado        pr_cta_prestamos.en_juicio%type,
                                fec_juicio           pr_cta_prestamos.fec_juicio%type,
                                cod_ent_juicio       pr_cta_prestamos.cod_ent_juicio%type,
                                informconf           varchar2(10),
                                fec_informconf       varchar2(10),
                                inhibido             varchar2(10),    
                                fec_inhibicion       varchar2(10),
                                fec_inicio           pr_cta_prestamos.fec_inicio%type,
                                mto_capital          pr_cta_prestamos.mto_capital%type,
                                sal_capital          pr_cta_prestamos.sal_capital%type,
                                sal_interes          pr_cta_prestamos.sal_interes%type,
                                sal_int_adelantado   pr_cta_prestamos.sal_int_adelantado%type,
                                monto                pr_cta_prestamos.monto%type,
                                dev_acumulado        pr_cta_prestamos.dev_acumulado%type,
                                dev_no_cobrado       pr_cta_prestamos.dev_no_cobrado%type,
                                dev_suspenso         pr_cta_prestamos.dev_suspenso%type,
                                fec_ult_devengado    pr_cta_prestamos.fec_ult_devengado%type,
                                tip_prestamo         pr_cta_prestamos.tipo%type,
                                tip_interes          pr_cta_prestamos.tip_interes%type,
                                val_tasa             pr_cta_prestamos.val_tasa%type,
                                estado               pr_cta_prestamos.estado%type,
                                cod_rub_primario     ba_personas.cod_rub_primario%type,
                                cod_rub_secundario   ba_personas.cod_rub_secundario%type,
                                cod_rub_terciario    ba_personas.cod_rub_terciario%type,
                                cod_rub_economico    pr_cta_prestamos.cod_rub_economico%type,
                                cod_sec_credito      pr_cta_prestamos.cod_sec_credito%type,
                                fec_ini              pr_cta_prestamos.fec_inicio%type,
                                cod_ofi_cliente      ge_clientes.cod_oficina%type,
                                cod_ofi_operacion    pr_cta_prestamos.cod_oficina%type,
                                ent_com_cartera      ge_cta_dat_adicionales.val_parametro%type,
                                cod_seg_cliente      ge_clientes.cod_seg_cliente%type,
                                tip_renovacion       pr_cta_prestamos.tip_renovacion%type,
                                fec_insercion        pr_cta_prestamos.fec_insercion%type,
                                fec_modificacion     pr_cta_prestamos.fec_modificacion%type,
                                descripcion          pr_cta_prestamos.descripcion%type,
                                cod_usu_oficial      ge_clientes.cod_usu_oficial%type,
                                fec_cancelacion      pr_cta_prestamos.fec_cancelacion%type,
                                cod_campana          pr_cta_prestamos.cod_campana%type);
    
    type tof_rec_cabecera is table of rec_cabecera;
    v_cabecera tof_rec_cabecera;

   cursor cabecera is
     select * 
       from IT.VM_CTA_COBRANZAS a
      where a.estado <> 'N'
     union all
     select *
       from IT.VM_CTA_COBRANZAS a
      where a.estado = 'N'
        and a.fec_modificacion >= (v_fecha - 15);
        
   TYPE rec_cuotas IS RECORD(nro_operacion        ge_cuentas.nro_cuenta%type,
                             nro_cuota            pr_cuotas.nro_cuota%type,
                             fec_vencimiento      varchar2(10),
                             fec_ult_pago         varchar2(10),
                             mto_capital          pr_cuotas.mto_capital%type,
                             sal_capital          pr_cuotas.sal_capital%type,
                             mto_interes          pr_cuotas.mto_interes%type,
                             sal_interes          pr_cuotas.sal_interes%type,
                             mto_int_descontado   pr_cuotas.mto_int_descontado%type,
                             dev_no_cobrado       pr_cuotas.dev_no_cobrado%type,
                             dev_suspenso         pr_cuotas.dev_suspenso%type,
                             dev_acumulado        pr_cuotas.dev_acumulado%type,
                             cod_banco            pr_rel_chq_lib.cod_banco%type,
                             cta_libradora        pr_rel_chq_lib.cta_libradora%type,
                             nro_cheque           pr_rel_chq_lib.nro_cheque%type,
                             fec_emision          varchar2(10),
                             mto_cheque           ge_che_custodias.monto%type,
                             nom_librador         varchar2(1000),
                             ape_librador         varchar2(1000),
                             nro_doc_librador     ba_personas.nro_documento%type,
                             cod_tip_doc_librador ba_personas.cod_tip_documento%type,
                             sexo_librador        ba_per_fisicas.cod_sexo%type,
                             cta_lib_denominacion pr_lib_cuentas.denominacion%type,
                             cod_oficina          ge_clientes.cod_oficina%type,
                             cod_cau_devolucion   ge_che_custodias.cod_cau_devolucion%type);
   
   type tof_rec_cuotas is table of rec_cuotas;
   v_cuotas tof_rec_cuotas;
         
   cursor cuotas(p_nro_cuenta varchar2) is
     select * 
       from it.ov_cta_cuo_cobranzas a
      where a.nro_operacion = p_nro_cuenta
      order by a.nro_operacion, a.nro_cuota;
      
   function fu_mto_car_desembolso(p_nro_cuenta varchar2)
     return number is
     v_mto_iva_desembolso number := 0;
     v_nro_solicitud pr_solicitudes.nro_solicitud%type;
   begin
     v_nro_solicitud := null;
     begin
       select a.nro_solicitud
         into v_nro_solicitud
         from pr_cta_prestamos a
        where a.nro_cuenta = p_nro_cuenta;
     exception
       when no_data_found then
         v_nro_solicitud := null;
       when others then
         v_nro_solicitud := null;
     end;
     if v_nro_solicitud is not null then
       begin
         select a.monto
           into v_mto_iva_desembolso
           from pr_sol_cargos a
          where a.nro_solicitud = v_nro_solicitud
            and a.cod_transaccion = 709;
       exception
         when no_data_found then
           v_mto_iva_desembolso := 0;
         when others then
           v_mto_iva_desembolso := 0;
       end;
     end if;
     return v_mto_iva_desembolso;
   end;
   
   function fu_rev_desembolso(p_nro_cuenta varchar2)
     return varchar2 is
     v_existe varchar2(1) := 'N';
   begin
     select distinct 'S'
       into v_existe
       from pr_movimientos_his a
      where a.nro_cuenta = p_nro_cuenta
        and a.cod_tra_padre = 358
        and a.reversado = 'S';
      return v_existe;
   exception
     when no_data_found then
       return 'N';
     when others then
       return 'N';
   end;
   
   begin
     if utl_file.is_open(v_arc_cab) then
        utl_file.fclose(v_arc_cab);
     end if;

     if utl_file.is_open(v_arc_det) then
        utl_file.fclose(v_arc_det);
     end if;

     v_nom_archivo := 'CR_IMP_PRE_CUENTAS_'||p_cod_entidad||'.CSV';
     v_arc_cab   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);

     v_reg_cab   :=  'COD_ENTE' || ';' ||
                     'NRO_OPERACION' || ';' ||
                     'COD_MONEDA' || ';' ||
                     'COD_MODALIDAD'|| ';' ||
                     'NOM_CLIENTE'|| ';' ||
                     'APE_CLIENTE'|| ';' ||
                     'TIPO'|| ';' ||
                     'NRO_DOC_CLIENTE'|| ';' ||
                     'COD_TIPO_DOC_CLIENTE'|| ';' ||
                     'SEXO'|| ';' ||
                     'CLI_CONFIDENCIAL'|| ';' ||
                     'CLI_ESPECIAL'|| ';' ||
                     'ES_FUNCIONARIO'|| ';' ||
                     'FEC_NACIMIENTO'|| ';' ||
                     'COD_RUB_PRIMARIO'|| ';' ||
                     'COD_RUB_SECUNDARIO'|| ';' ||
                     'COD_RUB_TERCIARIO'|| ';' ||
                     'COD_RUB_ECONOMICO'|| ';' ||
                     'COD_SEC_CREDITO'|| ';' ||
                     'RELACION'|| ';' ||
                     'NOM_CONYUGE'|| ';' ||
                     'APE_CONYUGE'|| ';' ||
                     'NRO_DOC_CONYUGE'|| ';' ||
                     'COD_TIP_DOC_CONYUGE'|| ';' ||
                     'SEXO_CONYUGE'|| ';' ||
                     'JUDICIALIZADO'|| ';' ||
                     'FEC_JUICIO'|| ';' ||
                     'COD_ENT_JUICIO'|| ';' ||
                     'INFORMCONF'|| ';' ||
                     'FEC_INFORMCONF'|| ';' ||
                     'INHIBIDO'|| ';' ||
                     'FEC_INHIBIDO'|| ';' ||
                     'FEC_INICIO'|| ';' ||
                     'MTO_CAPITAL'|| ';' ||
                     'SAL_CAPITAL'|| ';' ||
                     'SAL_INTERES'|| ';' ||
                     'SAL_INT_ADELANTADO'|| ';' ||
                     'MONTO'|| ';' ||
                     'DEV_ACUMULADO'|| ';' ||
                     'DEV_NO_COBRADO'||';'||
                     'DEV_SUSPENSO'||';'||
                     'FEC_ULT_DEVENGADO'||';' ||
                     'TIP_PRESTAMO'|| ';' ||
                     'TIP_INTERES'|| ';' ||
                     'VAL_TASA'|| ';' ||
                     'ESTADO'|| ';' ||
                     'MTO_IVA_DESEMBOLSO'|| ';' ||
                     'COD_OFI_CLIENTE'|| ';' ||
                     'COD_OFI_OPERACION'|| ';' ||
                     'ENT_COM_CARTERA'|| ';' ||
                     'COD_SEG_CLIENTE'|| ';' ||
                     'TIP_RENOVACION'|| ';' ||
                     'DESCRIPCION'||';'||
                     'FEC_MODIFICACION'|| ';' ||
                     'COD_USU_OFICIAL'|| ';' ||
                     'FEC_CANCELACION'|| ';' ||
                     'REV_DESEMBOLSO'|| ';' ||
                     'COD_CAMPANA';
     utl_file.put_line(v_arc_cab, v_reg_cab);
     p_archivo := v_arc_cab;
     --
     v_nom_arc_det := 'CR_IMP_PRE_CUOTAS_'||p_cod_entidad||'.CSV';
     v_arc_det     := utl_file.fopen(p_directorio, v_nom_arc_det, 'w', 32767);
     v_reg_det     :=  'COD_ENTE' || ';' ||
                       'NRO_OPERACION'|| ';' ||
                       'NRO_CUOTA'|| ';' ||
                       'FEC_VENCIMIENTO'|| ';' ||
                       'FEC_ULT_PAGO'|| ';' ||
                       'MTO_CAPITAL'|| ';' ||
                       'SAL_CAPITAL'|| ';' ||
                       'MTO_INTERES'|| ';' ||
                       'SAL_INTERES'|| ';' ||
                       'MTO_INT_DESCONTADO'|| ';' ||
                       'DEV_NO_COBRADO'|| ';' ||
                       'DEV_SUSPENSO'|| ';' ||
                       'DEV_ACUMULADO'|| ';' ||
                       'COD_BANCO'|| ';' ||
                       'CTA_LIBRADORA'|| ';' ||
                       'NRO_CHEQUE'|| ';' ||
                       'FEC_EMISION'|| ';' ||
                       'MTO_CHEQUE'|| ';' ||
                       'NOM_LIBRADOR'|| ';' ||
                       'APE_LIBRADOR'|| ';' ||
                       'NRO_DOC_LIBRADOR'|| ';' ||
                       'COD_TIP_DOC_LIBRADOR'|| ';' ||
                       'SEXO_LIBRADOR'|| ';' ||
                       'CTA_LIB_DENOMINACION'|| ';' ||
                       'COD_CAU_DEVOLUCION';
        utl_file.put_line(v_arc_det, v_reg_det);

    BEGIN
      OPEN cabecera;
      LOOP
        FETCH cabecera BULK COLLECT INTO v_cabecera LIMIT c_limit;
        EXIT WHEN v_cabecera.COUNT = 0;
        FOR i IN 1 .. v_cabecera.COUNT LOOP
         v_cont_cab  := v_cont_cab + 1;
         v_mto_iva_des := fu_mto_car_desembolso(v_cabecera(i).nro_operacion);
         v_rev_desembolso := 'N';
         if v_cabecera(i).estado = 'N' then
           v_rev_desembolso := fu_rev_desembolso(v_cabecera(i).nro_operacion);
         end if;
         v_reg_cab := p_cod_entidad|| ';' ||
                       v_cabecera(i).nro_operacion|| ';' ||
                       v_cabecera(i).cod_moneda|| ';' ||
                       v_cabecera(i).cod_modalidad|| ';' ||
                       v_cabecera(i).nom_cliente|| ';' ||
                       v_cabecera(i).ape_cliente|| ';' ||
                       v_cabecera(i).tipo|| ';' ||
                       v_cabecera(i).nro_doc_cliente|| ';' ||
                       v_cabecera(i).cod_tipo_doc_cliente|| ';' ||
                       v_cabecera(i).sexo|| ';' ||
                       v_cabecera(i).cli_confidencial|| ';' ||
                       v_cabecera(i).cli_especial|| ';' ||
                       v_cabecera(i).es_funcionario|| ';' ||
                       v_cabecera(i).fec_nacimiento|| ';' ||
                       v_cabecera(i).cod_rub_primario|| ';' ||
                       v_cabecera(i).cod_rub_secundario|| ';' ||
                       v_cabecera(i).cod_rub_terciario|| ';' ||
                       v_cabecera(i).cod_rub_economico|| ';' ||
                       v_cabecera(i).cod_sec_credito|| ';' ||
                       v_cabecera(i).RELACION|| ';' ||
                       v_cabecera(i).NOM_CONYUGE|| ';' ||
                       v_cabecera(i).APE_CONYUGE|| ';' ||
                       v_cabecera(i).NRO_DOC_CONYUGE|| ';' ||
                       v_cabecera(i).COD_TIP_DOC_CONYUGE|| ';' ||
                       v_cabecera(i).SEXO_CONYUGE|| ';' ||
                       v_cabecera(i).JUDICIALIZADO|| ';' ||
                       v_cabecera(i).FEC_JUICIO|| ';' ||
                       v_cabecera(i).cod_ent_juicio|| ';' ||
                       NULL|| ';' ||--INFORMCONF|| ';' ||
                       NULL|| ';' ||--FEC_INFORMCONF|| ';' ||
                       NULL|| ';' ||--INHIBIDO|| ';' ||
                       NULL|| ';' ||--FEC_INHIBICION|| ';' ||
                       v_cabecera(i).FEC_INICIO|| ';' ||
                       v_cabecera(i).MTO_CAPITAL|| ';' ||
                       v_cabecera(i).SAL_CAPITAL|| ';' ||
                       v_cabecera(i).SAL_INTERES|| ';' ||
                       v_cabecera(i).SAL_INT_ADELANTADO|| ';' ||
                       v_cabecera(i).MONTO|| ';' ||
                       v_cabecera(i).DEV_ACUMULADO|| ';' ||
                       v_cabecera(i).DEV_NO_COBRADO|| ';' ||
                       v_cabecera(i).DEV_SUSPENSO|| ';' ||
                       v_cabecera(i).FEC_ULT_DEVENGADO|| ';' ||
                       v_cabecera(i).TIP_PRESTAMO|| ';' ||
                       v_cabecera(i).TIP_INTERES|| ';' ||
                       v_cabecera(i).VAL_TASA|| ';' ||
                       v_cabecera(i).estado|| ';' ||
                       nvl(v_mto_iva_des,0)|| ';' ||
                       v_cabecera(i).cod_ofi_cliente|| ';' ||
                       v_cabecera(i).cod_ofi_operacion|| ';' ||
                       v_cabecera(i).ent_com_cartera|| ';' ||
                       v_cabecera(i).cod_seg_cliente|| ';' ||
                       v_cabecera(i).tip_renovacion|| ';' ||
                       v_cabecera(i).descripcion|| ';' ||
                       v_cabecera(i).fec_modificacion|| ';' ||
                       v_cabecera(i).cod_usu_oficial|| ';' ||
                       v_cabecera(i).fec_cancelacion|| ';' ||
                       v_rev_desembolso|| ';' ||
                       v_cabecera(i).cod_campana;

          utl_file.put_line(v_arc_cab, v_reg_cab);

          if v_cabecera(i).relacion = 'P' then
            -----Detalle Cuotas
            BEGIN
              OPEN cuotas(v_cabecera(i).nro_operacion);
              LOOP
                FETCH cuotas BULK COLLECT INTO v_cuotas LIMIT c_limit;
                EXIT WHEN v_cuotas.COUNT = 0;
                FOR i IN 1 .. v_cuotas.COUNT LOOP
                  v_cont_det:= v_cont_det + 1;
                  v_reg_det := p_cod_entidad|| ';' ||
                               v_cuotas(i).nro_operacion|| ';' ||
                               v_cuotas(i).nro_cuota || ';' ||
                               v_cuotas(i).fec_vencimiento|| ';' ||
                               v_cuotas(i).fec_ult_pago|| ';' ||
                               v_cuotas(i).mto_capital|| ';' ||
                               v_cuotas(i).sal_capital|| ';' ||
                               v_cuotas(i).mto_interes|| ';' ||
                               v_cuotas(i).sal_interes|| ';' ||
                               v_cuotas(i).mto_int_descontado|| ';' ||
                               v_cuotas(i).dev_no_cobrado|| ';' ||
                               v_cuotas(i).dev_suspenso|| ';' ||
                               v_cuotas(i).dev_acumulado|| ';' ||
                               v_cuotas(i).cod_banco|| ';' ||
                               v_cuotas(i).cta_libradora|| ';' ||
                               v_cuotas(i).nro_cheque|| ';' ||
                               v_cuotas(i).fec_emision|| ';' ||
                               v_cuotas(i).mto_cheque|| ';' ||
                               v_cuotas(i).nom_librador|| ';' ||
                               v_cuotas(i).ape_librador|| ';' ||
                               v_cuotas(i).nro_doc_librador|| ';' ||
                               v_cuotas(i).cod_tip_doc_librador|| ';' ||
                               v_cuotas(i).sexo_librador|| ';' ||
                               v_cuotas(i).cta_lib_denominacion|| ';' ||
                               v_cuotas(i).cod_cau_devolucion;
                   utl_file.put_line(v_arc_det, v_reg_det);
                END LOOP;
              END LOOP;
              CLOSE cuotas;
             END;    
          end if;
          
        end loop;
      END LOOP;
      CLOSE cabecera;
    END;
    v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
    lp_ins_log('LP_GEN_PRE_CUENTAS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
    
    v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
    lp_ins_log('LP_GEN_PRE_CUENTAS',v_hor_ini,v_hor_fin,v_nom_arc_det,v_cont_det);

    utl_file.fclose(v_arc_cab);
    utl_file.fclose(v_arc_det);
   end;

   PROCEDURE LP_GEN_PRE_PAGOS(p_archivo out UTL_FILE.FILE_TYPE,
                           p_directorio in varchar2,
                           p_cod_entidad in varchar2)
     IS
     v_registro     varchar2(8000);
     v_archivo      UTL_FILE.FILE_TYPE;
     v_tip_cobro    varchar2(10);
     
     TYPE rec_cobros IS RECORD( nro_operacion             pr_cobros.nro_cuenta%type,
                                nro_cuota                 pr_cobros.nro_cuota%type,
                                fec_pago                  pr_cobros.fecha%type,
                                hora                      pr_cobros.hora%type,
                                fec_ult_pago              pr_cobros.fec_ult_pago%type,
                                dia_mora                  pr_cobros.dia_mora%type,
                                mto_capital               pr_cobros.mto_capital%type,
                                mto_interes               pr_cobros.mto_interes%type,
                                mto_int_documentado       pr_cobros.mto_int_documentado%type,
                                mto_int_moratorio         pr_cobros.mto_int_moratorio%type,
                                mto_int_mor_interes       pr_cobros.mto_int_mor_interes%type,
                                mto_int_mor_adelantado    pr_cobros.mto_int_mor_adelantado%type,
                                mto_int_punitorio         pr_cobros.mto_int_punitorio%type,
                                mto_cargo                 pr_cobros.mto_cargo%type,
                                mto_car_iva               pr_cobros.mto_cargo_iva%type,
                                mto_impuesto              pr_cobros.mto_impuesto%type,
                                mto_int_descontado        pr_cobros.mto_int_descontado%type,
                                mto_int_mor_des           pr_cobros.mto_int_mor_des%type,
                                mto_int_mor_int_des       pr_cobros.mto_int_mor_int_des%type,
                                mto_int_mor_ade_des       pr_cobros.mto_int_mor_ade_des%type,
                                mto_int_pun_des           pr_cobros.mto_int_pun_des%type,
                                mto_car_des               pr_cobros.mto_car_des%type,
                                dev_no_cobrado            pr_cobros.dev_no_cobrado%type,
                                dev_suspenso              pr_cobros.dev_suspenso%type,
                                dev_acumulado             pr_cobros.dev_acumulado%type,
                                fec_valor                 pr_cobros.fec_valor%type,
                                mto_int_mor_cal           pr_cobros.mto_int_mor_cal%type,
                                mto_int_mor_int_cal       pr_cobros.mto_int_mor_int_cal%type,
                                mto_int_mor_ade_cal       pr_cobros.mto_int_mor_ade_cal%type,
                                mto_int_pun_cal           pr_cobros.mto_int_pun_cal%type,
                                mto_cargo_cal             pr_cobros.mto_cargo_cal%type,
                                mto_car_iva_cal           pr_cobros.mto_car_iva_cal%type,
                                mto_impuesto_cal          pr_cobros.mto_impuesto_cal%type,
                                nro_cta_renovada          pr_cta_prestamos.nro_cta_renovada%type,
                                usu_insercion             pr_cobros.usu_insercion%type);
     
     type tof_rec_cobros is table of rec_cobros;
     v_cobros tof_rec_cobros;
  
     cursor cobros is
           Select T.NRO_CUENTA NRO_OPERACION,
                  t.nro_cuota NRO_CUOTA,
                  to_char(t.fecha, 'DD/MM/YYYY') FEC_PAGO,
                  t.hora HORA,
                  to_char(T.FEC_ULT_PAGO, 'DD/MM/YYYY') FEC_ULT_PAGO,
                  T.DIA_MORA,
                  nvl(t.MTO_CAPITAL, 0) MTO_CAPITAL,
                  nvl(t.mto_interes, 0) MTO_INTERES,
                  nvl(t.mto_int_documentado, 0) MTO_INT_DOCUMENTADO,
                  nvl(T.MTO_INT_MORATORIO, 0) MTO_INT_MORATORIO,
                  nvl(T.MTO_INT_MOR_INTERES, 0) MTO_INT_MOR_INTERES,
                  nvl(T.MTO_INT_MOR_ADELANTADO, 0) MTO_INT_MOR_ADELANTADO,
                  nvl(T.MTO_INT_PUNITORIO, 0) MTO_INT_PUNITORIO,
                  nvl(T.MTO_CARGO, 0) MTO_CARGO,
                  nvl(T.MTO_CARGO_IVA, 0) MTO_CAR_IVA,
                  nvl(T.MTO_IMPUESTO, 0) MTO_IMPUESTO,
                  nvl(T.MTO_INT_DESCONTADO, 0) MTO_INT_DESCONTADO,
                  nvl(T.MTO_INT_MOR_DES,0) MTO_INT_MOR_DES,
                  nvl(T.MTO_INT_MOR_INT_DES,0) MTO_INT_MOR_INT_DES,
                  nvl(T.MTO_INT_MOR_ADE_DES,0) MTO_INT_MOR_ADE_DES,
                  nvl(T.MTO_INT_PUN_DES,0) MTO_INT_PUN_DES,
                  nvl(T.MTO_CAR_DES,0) MTO_CAR_DES,
                  nvl(T.DEV_NO_COBRADO,0) DEV_NO_COBRADO,
                  nvl(T.DEV_SUSPENSO,0) DEV_SUSPENSO,
                  nvl(T.DEV_ACUMULADO,0) DEV_ACUMULADO,
                  to_char(T.FEC_VALOR,'DD/MM/YYYY') FEC_VALOR,
                  NVL(T.MTO_INT_MOR_CAL,0) MTO_INT_MOR_CAL,
                  NVL(T.MTO_INT_MOR_INT_CAL,0) MTO_INT_MOR_INT_CAL,
                  NVL(T.MTO_INT_MOR_ADE_CAL,0) MTO_INT_MOR_ADE_CAL,
                  NVL(T.MTO_INT_PUN_CAL,0) MTO_INT_PUN_CAL,
                  NVL(T.MTO_CARGO_CAL,0) MTO_CARGO_CAL,
                  NVL(T.MTO_CAR_IVA_CAL,0) MTO_CAR_IVA_CAL,
                  NVL(T.MTO_IMPUESTO_CAL,0) MTO_IMPUESTO_CAL,
                  fug_obt_cta_renovada(t.nro_cuenta,
                                       t.nro_cuota,
                                       t.fecha,
                                       t.hora) nro_cta_renovada,
                  T.USU_INSERCION
        from pr_cobros        t,
             pr_cta_prestamos p,
             ge_cta_clientes  g
       where t.nro_cuenta = p.nro_cuenta
         and t.nro_cuenta = g.nro_cuenta
         and g.relacion = 'P'
         and t.fecha = v_fecha
       union all -- Reversiones históricas
       select distinct a.nro_cuenta,
              a.nro_documento3,
              to_char(a.fec_valor, 'dd/mm/yyyy'),
              a.hor_reversion,
              null,
              null,
              -1 mto_capital,
              -1 mto_interes,
              0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
              null,
              0,0,0,0,0,0,0,
              null,
              null
         from pr_movimientos_his a
        where a.fecha = v_fecha
          and a.reversado = 'S'
          and a.cod_tra_padre in (360,364,359,361)
          and a.cod_modulo = 6
          and a.nro_cuenta is not null
       order by 1, 2, 3, 4, 5;

   BEGIN
     v_nom_archivo := 'CR_IMP_PRE_COBROS_'||p_cod_entidad||'.CSV';
     v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
     v_registro := 'COD_ENTE' || ';' ||
                   'NRO_OPERACION'|| ';' ||
                   'NRO_CUOTA'|| ';' ||
                   'FEC_PAGO'|| ';' ||
                   'HORA'|| ';' ||
                   'FEC_ULT_PAGO'|| ';' ||
                   'DIA_MORA'|| ';' ||
                   'MTO_CAPITAL'|| ';' ||
                   'MTO_INTERES'|| ';' ||
                   'MTO_INT_DOCUMENTADO'|| ';' ||
                   'MTO_INT_MORATORIO'|| ';' ||
                   'MTO_INT_MOR_INTERES'|| ';' ||
                   'MTO_INT_MOR_ADELANTADO'|| ';' ||
                   'MTO_INT_PUNITORIO'|| ';' ||
                   'MTO_CARGO'|| ';' ||
                   'MTO_CAR_IVA'|| ';' ||
                   'MTO_IMPUESTO'|| ';' ||
                   'MTO_INT_DESCONTADO'|| ';' ||
                   'MTO_INT_MOR_DES'|| ';' ||
                   'MTO_INT_MOR_INT_DES'|| ';' ||
                   'MTO_INT_MOR_ADE_DES'|| ';' ||
                   'MTO_INT_PUN_DES'|| ';' ||
                   'MTO_CAR_DES'|| ';' ||
                   'DEV_NO_COBRADO'|| ';' ||
                   'DEV_SUSPENSO'|| ';' ||
                   'DEV_ACUMULADO'|| ';' ||
                   'FEC_VALOR'|| ';' ||
                   'MTO_INT_MOR_CAL'|| ';' ||
                   'MTO_INT_MOR_INT_CAL'|| ';' ||
                   'MTO_INT_MOR_ADE_CAL'|| ';' ||
                   'MTO_INT_PUN_CAL'|| ';' ||
                   'MTO_CARGO_CAL'|| ';' ||
                   'MTO_CAR_IVA_CAL'|| ';' ||
                   'MTO_IMPUESTO_CAL'|| ';' ||
                   'NRO_CTA_RENOVADA'|| ';' ||
                   'USU_INSERCION'|| ';' ||
                   'TIP_COBRO';
     utl_file.put_line(v_archivo, v_registro);
     BEGIN
       OPEN cobros;
        LOOP
          FETCH cobros BULK COLLECT INTO v_cobros LIMIT c_limit;
          EXIT WHEN v_cobros.COUNT = 0;

          FOR i IN 1 .. v_cobros.COUNT LOOP
            v_cont_cab  := v_cont_cab + 1;
            v_tip_cobro := null;
            if v_cobros(i).mto_capital > 0 then
              v_tip_cobro := fu_obt_tip_cobro(v_cobros(i).nro_operacion, v_cobros(i).nro_cuota, v_cobros(i).fec_pago, v_cobros(i).hora);
            end if;
              v_registro := p_cod_entidad|| ';' ||
                            v_cobros(i).NRO_OPERACION|| ';' ||
                            v_cobros(i).NRO_CUOTA|| ';' ||
                            v_cobros(i).FEC_PAGO|| ';' ||
                            v_cobros(i).HORA|| ';' ||
                            v_cobros(i).fec_ult_pago|| ';' ||
                            v_cobros(i).dia_mora|| ';' ||
                            v_cobros(i).MTO_CAPITAL|| ';' ||
                            v_cobros(i).MTO_INTERES|| ';' ||
                            v_cobros(i).MTO_INT_DOCUMENTADO|| ';' ||
                            v_cobros(i).MTO_INT_MORATORIO|| ';' ||
                            v_cobros(i).MTO_INT_MOR_INTERES|| ';' ||
                            v_cobros(i).MTO_INT_MOR_ADELANTADO|| ';' ||
                            v_cobros(i).MTO_INT_PUNITORIO|| ';' ||
                            v_cobros(i).MTO_CARGO|| ';' ||
                            v_cobros(i).mto_car_iva|| ';' ||
                            v_cobros(i).MTO_IMPUESTO|| ';' ||
                            v_cobros(i).mto_int_descontado|| ';' ||
                            v_cobros(i).mto_int_mor_des|| ';' ||
                            v_cobros(i).mto_int_mor_int_des|| ';' ||
                            v_cobros(i).mto_int_mor_ade_des|| ';' ||
                            v_cobros(i).mto_int_pun_des|| ';' ||
                            v_cobros(i).mto_car_des|| ';' ||
                            v_cobros(i).dev_no_cobrado|| ';' ||
                            v_cobros(i).dev_suspenso|| ';' ||
                            v_cobros(i).dev_acumulado|| ';' ||
                            v_cobros(i).fec_valor|| ';' ||
                            v_cobros(i).mto_int_mor_cal|| ';' ||
                            v_cobros(i).mto_int_mor_int_cal|| ';' ||
                            v_cobros(i).mto_int_mor_ade_cal|| ';' ||
                            v_cobros(i).mto_int_pun_cal|| ';' ||
                            v_cobros(i).mto_cargo_cal|| ';' ||
                            v_cobros(i).mto_car_iva_cal|| ';' ||
                            v_cobros(i).mto_impuesto_cal|| ';' ||
                            v_cobros(i).nro_cta_renovada|| ';' ||
                            v_cobros(i).usu_insercion|| ';' ||
                            v_tip_cobro;
             utl_file.put_line(v_archivo, v_registro);
          end loop;
        end loop;
        CLOSE cobros;
     END;     
     v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
     lp_ins_log('LP_GEN_PRE_PAGOS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
     utl_file.fclose(v_archivo);
     p_archivo := v_archivo;
   END;
--
PROCEDURE LP_GEN_OVE_VENCIDA(p_archivo out UTL_FILE.FILE_TYPE,
                            p_directorio in varchar2,
                            p_cod_entidad in varchar2)
     IS
    v_reg_cab      varchar2(8000);
    v_arc_cab      UTL_FILE.FILE_TYPE;
    v_arc_det      UTL_FILE.FILE_TYPE;

   cursor cabecera is
     select * from ov_ope_vencidas a
      where (a.estado <> 'N'
         or (a.estado = 'N' and a.fec_modificacion >= v_fecha -15));

   begin
     if utl_file.is_open(v_arc_cab) then
        utl_file.fclose(v_arc_cab);
     end if;

     if utl_file.is_open(v_arc_det) then
        utl_file.fclose(v_arc_det);
     end if;

     v_nom_archivo := 'CR_IMP_OVE_CUENTAS_'||p_cod_entidad||'.CSV';
     v_arc_cab   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);

     v_reg_cab   := 'COD_ENTE' || ';' ||
                    'NRO_OPERACION'||';'||
                    'COD_MONEDA'||';'||
                    'COD_MODALIDAD'||';'||
                    'NOM_CLIENTE'||';'||
                    'APE_CLIENTE'||';'||
                    'TIPO'||';'||
                    'NRO_DOC_CLIENTE'||';'||
                    'COD_TIPO_DOC_CLIENTE'||';'||
                    'SEXO'||';'||
                    'CLI_CONFIDENCIAL'||';'||
                    'CLI_ESPECIAL'||';'||
                    'ES_FUNCIONARIO'||';'||
                    'FEC_NACIMIENTO'||';'||
                    'RELACION'||';'||
                    'NOM_CONYUGE'||';'||
                    'APE_CONYUGE'||';'||
                    'NRO_DOC_CONYUGE'||';'||
                    'COD_TIP_DOC_CONYUGE'||';'||
                    'SEXO_CONYUGE'||';'||
                    'JUDICIALIZADO'||';'||
                    'FEC_JUICIO'||';'||
                    'COD_ENT_JUICIO'||';'||
                    'INFORMCONF'||';'||
                    'FEC_INFORMCONF'||';'||
                    'INHIBIDO'||';'||
                    'FEC_INHIBICION'||';'||
                    'MTO_ORIGEN'||';'||
                    'VAL_TASA'||';'||
                    'ESTADO'||';'||
                    'COD_RUB_PRIMARIO'||';'||
                    'COD_RUB_SECUNDARIO'||';'||
                    'COD_RUB_TERCIARIO'||';'||
                    'COD_RUB_ECONOMICO'||';'||
                    'COD_OFI_CLIENTE'||';'||
                    'COD_OFI_OPERACION'||';'||
                    'ENT_COM_CARTERA'||';'||
                    'COD_SEG_CLIENTE'||';'||
                    'FEC_INSERCION'||';'||
                    'DENOMINACION'||';'||
                    'NRO_CTA_ORIGEN'||';'||
                    'FEC_APERTURA'||';'||
                    'SAL_TOT_BATCH'||';'||
                    'DIA_ATRASO'||';'||
                    'DIA_ATR_INICIAL'||';'||
                    'SAL_TOTAL'||';'||
                    'SAL_ANTERIOR'||';'||
                    'FEC_INI_MORA'||';'||
                    'FEC_MODIFICACION'||';'||
                    'COD_USU_OFICIAL';
     utl_file.put_line(v_arc_cab, v_reg_cab);
     p_archivo := v_arc_cab;
    for c in cabecera loop
       v_cont_cab := v_cont_cab + 1;
       
       v_reg_cab := p_cod_entidad|| ';' ||
                    c.nro_operacion||';'||
                    c.cod_moneda||';'||
                    c.cod_modalidad||';'||
                    c.nom_cliente||';'||
                    c.ape_cliente||';'||
                    c.tipo||';'||
                    c.nro_doc_cliente||';'||
                    c.cod_tipo_doc_cliente||';'||
                    c.sexo||';'||
                    c.cli_confidencial||';'||
                    c.cli_especial||';'||
                    c.es_funcionario||';'||
                    c.fec_nacimiento||';'||
                    c.relacion||';'||
                    c.nom_conyuge||';'||
                    c.ape_conyuge||';'||
                    c.nro_doc_conyuge||';'||
                    c.cod_tip_doc_conyuge||';'||
                    c.sexo_conyuge||';'||
                    c.judicializado||';'||
                    c.fec_juicio||';'||
                    c.cod_ent_juicio||';'||
                    c.informconf||';'||
                    c.fec_informconf||';'||
                    c.inhibido||';'||
                    c.fec_inhibicion||';'||
                    c.mto_origen||';'||
                    c.val_tasa||';'||
                    c.estado||';'||
                    c.cod_rub_primario||';'||
                    c.cod_rub_secundario||';'||
                    c.cod_rub_terciario||';'||
                    c.cod_rub_economico||';'||
                    c.cod_ofi_cliente||';'||
                    c.cod_ofi_operacion||';'||
                    c.ent_com_cartera||';'||
                    c.cod_seg_cliente||';'||
                    c.fec_insercion||';'||
                    c.denominacion||';'||
                    c.nro_cta_origen||';'||
                    c.fec_apertura||';'||
                    c.sal_tot_batch||';'||
                    c.dia_atraso||';'||
                    c.dia_atr_inicial||';'||
                    c.sal_total||';'||
                    c.sal_anterior||';'||
                    c.fec_ini_mora||';'||
                    c.fec_modificacion||';'||
                    c.cod_usu_oficial;
      utl_file.put_line(v_arc_cab, v_reg_cab);
    end loop;
    v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
    lp_ins_log('LP_GEN_OVE_VENCIDA',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);

    utl_file.fclose(v_arc_cab);
    utl_file.fclose(v_arc_det);
   end;

PROCEDURE LP_GEN_OVE_PAGOS(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
       IS
       v_registro     varchar2(8000);
       v_archivo      UTL_FILE.FILE_TYPE;
       cursor c_cobros is select * from ov_cobros a;

     BEGIN
       v_nom_archivo := 'CR_IMP_OVE_COBROS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_OPERACION'||';'||
                      'FECHA'||';'||
                      'HORA'||';'||
                      'ESTADO'||';'||
                      'SAL_TOTAL'||';'||
                      'FEC_ULT_PAGO'||';'||
                      'DIA_MORA'||';'||
                      'MTO_TOTAL'||';'||
                      'MTO_INT_MORATORIO'||';'||
                      'MTO_INT_PUNITORIO'||';'||
                      'MTO_CARGO'||';'||
                      'MTO_CARGO_IVA'||';'||
                      'MTO_IMPUESTO'||';'||
                      'NRO_DOCUMENTO'||';'||
                      'MTO_INT_MOR_CAL'||';'||
                      'MTO_INT_PUN_CAL'||';'||
                      'MTO_CARGO_CAL'||';'||
                      'MTO_CAR_IVA_CAL'||';'||
                      'MTO_IMPUESTO_CAL'||';'||
                      'USU_INSERCION'||';'||
                      'FEC_INSERCION'||';'||
                      'USU_MODIFICACION'||';'||
                      'FEC_MODIFICACION'||';'||
                      'MTO_CAR_DES'||';'||
                      'MTO_INT_MOR_DES'||';'||
                      'MTO_INT_PUN_DES';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cobros loop
            v_cont_cab  := v_cont_cab + 1;
            
            v_registro := p_cod_entidad|| ';' ||
                          c.nro_cuenta||';'||
                          c.fecha||';'||
                          c.hora||';'||
                          c.estado||';'||
                          c.sal_total||';'||
                          c.fec_ult_pago||';'||
                          c.dia_mora||';'||
                          c.mto_total||';'||
                          c.mto_int_moratorio||';'||
                          c.mto_int_punitorio||';'||
                          c.mto_cargo||';'||
                          c.mto_cargo_iva||';'||
                          c.mto_impuesto||';'||
                          c.nro_documento||';'||
                          c.mto_int_mor_cal||';'||
                          c.mto_int_pun_cal||';'||
                          c.mto_cargo_cal||';'||
                          c.mto_car_iva_cal||';'||
                          c.mto_impuesto_cal||';'||
                          c.usu_insercion||';'||
                          c.fec_insercion||';'||
                          c.usu_modificacion||';'||
                          c.fec_modificacion||';'||
                          c.mto_car_des||';'||
                          c.mto_int_mor_des||';'||
                          c.mto_int_pun_des;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_OVE_PAGOS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;
--

 PROCEDURE LP_GEN_TAR_CUENTAS(p_archivo out UTL_FILE.FILE_TYPE,
                              p_directorio in varchar2,
                              p_cod_entidad in varchar2) IS
  v_registro    varchar2(8000);
  v_archivo     UTL_FILE.FILE_TYPE;
  v_nom_arc_tar varchar2(30);
  v_reg_tar     varchar2(8000);
  v_arc_tar     UTL_FILE.FILE_TYPE;
  
  TYPE rec_tar_cuentas IS RECORD( nro_operacion        ge_cuentas.nro_cuenta%type,
                                  nom_cliente          varchar2(1000),
                                  ape_cliente          varchar2(1000),
                                  tipo                 ba_personas.tipo%type,
                                  cod_tip_documento    ba_personas.cod_tip_documento%type,
                                  nro_doc_cliente      ba_personas.nro_documento%type,
                                  cod_tipo_doc_cliente ba_personas.cod_tip_documento%type,
                                  sexo                 ba_per_fisicas.cod_sexo%type,                                
                                  cli_confidencial     ge_clientes.cli_confidencial%type,
                                  cli_especial         ge_clientes.cli_especial%type,
                                  es_funcionario       varchar2(1),
                                  relacion             ge_cta_clientes.relacion%type,
                                  nom_conyuge          varchar2(1000),
                                  ape_conyuge          varchar2(1000),
                                  nro_doc_conyuge      ba_personas.nro_documento%type,
                                  cod_tip_doc_conyuge  ba_personas.cod_tip_documento%type,
                                  sexo_conyuge         ba_per_fisicas.cod_sexo%type,
                                  denominacion         ta_cta_tarjetas.denominacion%type,
                                  cod_modulo           ta_cta_tarjetas.cod_modulo%type,
                                  cod_modalidad        ta_cta_tarjetas.cod_modalidad%type,
                                  cod_oficina          ta_cta_tarjetas.cod_oficina%type,
                                  cod_moneda           ta_cta_tarjetas.cod_moneda%type,
                                  lin_credito          ta_cta_tarjetas.lin_credito%type,
                                  lin_cuotas           ta_cta_tarjetas.lin_cuotas%type,
                                  sal_facturar         ta_cta_tarjetas.sal_facturar%type,
                                  sal_facturado        ta_cta_tarjetas.sal_facturado%type,
                                  sal_financiado       ta_cta_tarjetas.sal_financiado%type,
                                  sal_ult_extracto     ta_cta_tarjetas.sal_ult_extracto%type,
                                  sal_cuo_pendientes   ta_cta_tarjetas.sal_cuo_pendientes%type,
                                  mto_pag_minimo       ta_cta_tarjetas.mto_pag_minimo%type,
                                  sal_pag_minimo       ta_cta_tarjetas.sal_pag_minimo%type,
                                  mto_mora             ta_cta_tarjetas.mto_mora%type,
                                  dia_mora             ta_cta_tarjetas.dia_mora%type,
                                  mto_autorizaciones   ta_cta_tarjetas.mto_autorizaciones%type,
                                  mto_int_compras      ta_cta_tarjetas.mto_int_compras%type,
                                  mto_pag_mes          ta_cta_tarjetas.mto_pag_mes%type,
                                  mto_gas_mora         ta_cta_tarjetas.mto_gas_mora%type,
                                  estado               ta_cta_tarjetas.estado%type,
                                  est_administradora   ta_cta_tarjetas.est_administradora%type,
                                  fec_solicitud        varchar2(100),--ta_cta_tarjetas.fec_solicitud%type,
                                  fec_apertura         varchar2(100),--ta_cta_tarjetas.fec_apertura%type,
                                  fec_ult_pago         varchar2(100),--ta_cta_tarjetas.fec_ult_pago%type,
                                  fec_ult_compra       varchar2(100),--ta_cta_tarjetas.fec_ult_compra%type,
                                  fec_ult_operacion    varchar2(100),--ta_cta_tarjetas.fec_ult_operacion%type,
                                  fec_ult_extracto     varchar2(100),--ta_cta_tarjetas.fec_ult_extracto%type,
                                  fec_ult_cierre       varchar2(100),--ta_cta_tarjetas.fec_ult_cierre%type,
                                  fec_vct_ult_cierre   varchar2(100),--ta_cta_tarjetas.fec_vct_ult_cierre%type,
                                  tip_cierre           ta_cta_tarjetas.tip_cierre%type,
                                  cob_gas_financiero   ta_cta_tarjetas.cob_gas_financiero%type,
                                  tip_tas_financiacion ta_cta_tarjetas.tip_tas_financiacion%type,
                                  tip_com_emision      ta_cta_tarjetas.tip_com_emision%type,
                                  tas_financiacion     ta_cta_tarjetas.tas_financiacion%type,
                                  tas_adelanto         ta_cta_tarjetas.tas_adelanto%type,
                                  tas_mora             ta_cta_tarjetas.tas_mora%type,
                                  tas_cuotas           ta_cta_tarjetas.tas_cuotas%type,
                                  deb_automatico       ta_cta_tarjetas.deb_automatico%type,
                                  tip_cobro            ta_cta_tarjetas.tip_cobro%type,
                                  nro_cta_debito       ta_cta_tarjetas.nro_cta_debito%type,
                                  mto_min_pago         ta_cta_tarjetas.mto_min_pago%type,
                                  por_pag_minimo       ta_cta_tarjetas.por_pag_minimo%type,
                                  cod_usu_promotor     ta_cta_tarjetas.cod_usu_promotor%type,
                                  mar_mora             ta_cta_tarjetas.mar_mora%type,
                                  mar_excedido         ta_cta_tarjetas.mar_excedido%type,
                                  mar_recuperado       ta_cta_tarjetas.mar_recuperado%type,
                                  mar_bloqueo          ta_cta_tarjetas.mar_bloqueo%type,
                                  con_costo            ta_cta_tarjetas.con_costo%type,
                                  nro_solicitud        ta_cta_tarjetas.nro_solicitud%type,
                                  cod_causa            ta_cta_tarjetas.cod_causa%type,
                                  cod_canal            ta_cta_tarjetas.cod_canal%type,
                                  cod_campana          ta_cta_tarjetas.cod_campana%type,
                                  cat_automatica       ta_cta_tarjetas.cat_automatica%type,
                                  fec_juicio           varchar2(100),--ta_cta_tarjetas.fec_juicio%type,
                                  cod_ent_juicio       ta_cta_tarjetas.cod_ent_juicio%type,
                                  max_atraso           ta_cta_tarjetas.max_atraso%type,
                                  pro_atraso           ta_cta_tarjetas.pro_atraso%type,
                                  nro_linea            ta_cta_tarjetas.nro_linea%type,
                                  en_juicio            ta_cta_tarjetas.en_juicio%type,
                                  cat_aut_anterior     ta_cta_tarjetas.cat_aut_anterior%type,
                                  fec_activacion       varchar2(100),--ta_cta_tarjetas.fec_activacion%type,
                                  fec_cancelacion      varchar2(100),--ta_cta_tarjetas.fec_cancelacion%type,
                                  tas_efectiva         ta_cta_tarjetas.tas_efectiva%type,
                                  mto_aut_cuotas       ta_cta_tarjetas.mto_aut_cuotas%type,
                                  afinidad             ta_cta_tarjetas.afinidad%type,
                                  sub_afinidad         ta_cta_tarjetas.sub_afinidad%type,
                                  sal_procesadora      ta_cta_tarjetas.sal_procesadora%type,
                                  cod_rub_economico    ta_cta_tarjetas.cod_rub_economico%type,
                                  cod_tip_cierre       ta_cta_tarjetas.cod_tip_cierre%type,
                                  franqueo             ta_cta_tarjetas.franqueo%type,
                                  ind_seg_vida         ta_cta_tarjetas.ind_seg_vida%type,
                                  cod_exc_cargo        ta_cta_tarjetas.cod_exc_cargo%type,
                                  lin_especial         ta_cta_tarjetas.lin_especial%type,
                                  tas_especial         ta_cta_tarjetas.tas_especial%type,
                                  mto_car_suspendido   ta_cta_tarjetas.mto_car_suspendido%type,
                                  mto_car_sus_aplicado ta_cta_tarjetas.mto_car_sus_aplicado%type,
                                  fec_modificacion     ta_cta_tarjetas.fec_modificacion%type,
                                  cod_ofi_cliente      ge_clientes.cod_oficina%type,
                                  cod_ofi_operacion    ta_cta_tarjetas.cod_oficina%type,
                                  cod_seg_cliente      ge_clientes.cod_seg_cliente%type,
                                  cod_usu_oficial      ge_clientes.cod_usu_oficial%type,
                                  fec_cierre           varchar2(100),--ta_sal_cierres.fec_cierre%type,
                                  mto_pag_min_cierre   ta_sal_cierres.mto_pag_minimo%type,
                                  fec_vto_pago         varchar2(100)--ta_sal_cierres.fec_vto_pago%type
                                  );                             
  
  type tof_tar_cuentas is table of rec_tar_cuentas;
  v_tar_cuentas tof_tar_cuentas;
  
  cursor c_tar_cuentas is
  select c.*, d.fec_cierre, d.mto_pag_min_cierre, d.fec_vto_pago
    from it.vm_cta_tarjetas c,
         (select a.nro_cuenta, a.fec_cierre, a.mto_pag_minimo mto_pag_min_cierre, a.fec_vto_pago
            from ta_sal_cierres a
           where a.fec_cierre = (select max(b.fec_cierre)
                                   from ta_sal_cierres b
                                  where b.nro_cuenta = a.nro_cuenta)) d
   where d.nro_cuenta(+) = c.nro_operacion
     and (c.estado <> 'C' or (c.estado = 'C' and c.fec_modificacion >= v_fecha-15));
  --
  
  TYPE rec_tarjetas IS RECORD(nro_cuenta        ge_cuentas.nro_cuenta%type,
                              nro_tarjeta       ta_tarjetas.nro_tarjeta%type,
                              nro_documento     ba_personas.nro_documento%type,
                              cod_tip_documento ba_personas.cod_tip_documento%type,   
                              cod_estado        ta_tarjetas.cod_estado%type,
                              fec_vencimiento   varchar2(100),
                              cod_causa         ta_tarjetas.cod_causa%type,
                              nom_embozar       ta_tarjetas.nom_embozar%type,
                              nom_enviar        ta_tarjetas.nom_enviar%type,
                              vigente           ta_tarjetas.vigente%type,
                              fec_emision       varchar2(100),
                              fec_solicitud     varchar2(100),
                              tip_envio         ta_tarjetas.tip_envio%type,
                              referencia        ta_tarjetas.referencia%type,
                              nro_planilla      ta_tarjetas.nro_planilla%type,
                              tip_planilla      ta_tarjetas.tip_planilla%type,
                              nro_pla_anterior  ta_tarjetas.nro_pla_anterior%type,
                              fec_entrega       varchar2(100),
                              fec_activacion    varchar2(100),
                              observacion       ta_tarjetas.observacion%type,
                              pre_embozada      ta_tarjetas.pre_embozada%type,
                              rel_tarjeta       ta_tarjetas.rel_tarjeta%type);
  
  type tof_tarjetas is table of rec_tarjetas;
  v_tarjetas tof_tarjetas;
  
  cursor c_tar_tarjetas is
  select nro_cuenta,
         nro_tarjeta,
         b.nro_documento,
         b.cod_tip_documento,
         cod_estado,
         to_char(fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
         cod_causa,
         nom_embozar,
         nom_enviar,
         vigente,
         to_char(fec_emision,'dd/mm/yyyy') fec_emision,
         to_char(fec_solicitud,'dd/mm/yyyy') fec_solicitud,
         tip_envio,
         referencia,
         nro_planilla,
         tip_planilla,
         nro_pla_anterior,
         to_char(fec_entrega,'dd/mm/yyyy') fec_entrega,
         to_char(fec_activacion,'dd/mm/yyyy') fec_activacion,
         observacion,
         pre_embozada,
         rel_tarjeta
    from ta_tarjetas a, ba_personas b
   where b.cod_persona = a.cod_persona;
BEGIN
  if utl_file.is_open(v_archivo) then
    utl_file.fclose(v_archivo);
  end if;

  v_nom_archivo := 'CR_IMP_TAR_CUENTAS_'||p_cod_entidad||'.CSV';
  v_archivo     := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);

  v_registro  := 'COD_ENTE' || ';' ||
                 'NRO_OPERACION' || ';' ||
                 'COD_MONEDA'|| ';' ||
                 'COD_MODALIDAD'|| ';' ||
                 'NOM_CLIENTE'|| ';' ||
                 'APE_CLIENTE'|| ';' ||
                 'TIPO'|| ';' ||
                 'NRO_DOC_CLIENTE'|| ';' ||
                 'COD_TIPO_DOC_CLIENTE'|| ';' ||
                 'SEXO'|| ';' ||
                 'CLI_CONFIDENCIAL'|| ';' ||
                 'CLI_ESPECIAL'|| ';' ||
                 'ES_FUNCIONARIO'|| ';' ||
                 'RELACION'|| ';' ||
                 'NOM_CONYUGE'|| ';' ||
                 'APE_CONYUGE'|| ';' ||
                 'NRO_DOC_CONYUGE'|| ';' ||
                 'COD_TIP_DOC_CONYUGE'|| ';' ||
                 'SEXO_CONYUGE'|| ';' ||
                 'DENOMINACION'|| ';' ||
                 'COD_MODULO'|| ';' ||
                 'COD_OFICINA'|| ';' ||
                 'LIN_CREDITO'|| ';' ||
                 'LIN_CUOTAS'|| ';' ||
                 'SAL_FACTURAR'|| ';' ||
                 'SAL_FACTURADO'|| ';' ||
                 'SAL_FINANCIADO'|| ';' ||
                 'SAL_ULT_EXTRACTO'|| ';' ||
                 'SAL_CUO_PENDIENTES'|| ';' ||
                 'MTO_PAG_MINIMO'|| ';' ||
                 'SAL_PAG_MINIMO'|| ';' ||
                 'MTO_MORA'|| ';' ||
                 'DIA_MORA'|| ';' ||
                 'MTO_AUTORIZACIONES'|| ';' ||
                 'MTO_INT_COMPRAS'|| ';' ||
                 'MTO_PAG_MES'|| ';' ||
                 'MTO_GAS_MORA'|| ';' ||
                 'ESTADO'|| ';' ||
                 'EST_ADMINISTRADORA'|| ';' ||
                 'FEC_SOLICITUD'|| ';' ||
                 'FEC_APERTURA'|| ';' ||
                 'FEC_ULT_PAGO'|| ';' ||
                 'FEC_ULT_COMPRA'|| ';' ||
                 'FEC_ULT_OPERACION'|| ';' ||
                 'FEC_ULT_EXTRACTO'|| ';' ||
                 'FEC_ULT_CIERRE'|| ';' ||
                 'FEC_VCT_ULT_CIERRE'|| ';' ||
                 'TIP_CIERRE'|| ';' ||
                 'COB_GAS_FINANCIERO'|| ';' ||
                 'TIP_TAS_FINANCIACION'|| ';' ||
                 'TIP_COM_EMISION'|| ';' ||
                 'TAS_FINANCIACION'|| ';' ||
                 'TAS_ADELANTO'|| ';' ||
                 'TAS_MORA'|| ';' ||
                 'TAS_CUOTAS'|| ';' ||
                 'DEB_AUTOMATICO'|| ';' ||
                 'TIP_COBRO'|| ';' ||
                 'NRO_CTA_DEBITO'|| ';' ||
                 'MTO_MIN_PAGO'|| ';' ||
                 'POR_PAG_MINIMO'|| ';' ||
                 'COD_USU_PROMOTOR'|| ';' ||
                 'MAR_MORA'|| ';' ||
                 'MAR_EXCEDIDO'|| ';' ||
                 'MAR_RECUPERADO'|| ';' ||
                 'MAR_BLOQUEO'|| ';' ||
                 'CON_COSTO'|| ';' ||
                 'NRO_SOLICITUD'|| ';' ||
                 'COD_CAUSA'|| ';' ||
                 'COD_CANAL'|| ';' ||
                 'COD_CAMPANA'|| ';' ||
                 'CAT_AUTOMATICA'|| ';' ||
                 'FEC_JUICIO'|| ';' ||
                 'COD_ENT_JUICIO'|| ';' ||
                 'MAX_ATRASO'|| ';' ||
                 'PRO_ATRASO'|| ';' ||
                 'NRO_LINEA'|| ';' ||
                 'EN_JUICIO'|| ';' ||
                 'CAT_AUT_ANTERIOR'|| ';' ||
                 'FEC_ACTIVACION'|| ';' ||
                 'FEC_CANCELACION'|| ';' ||
                 'TAS_EFECTIVA'|| ';' ||
                 'MTO_AUT_CUOTAS'|| ';' ||
                 'AFINIDAD'|| ';' ||
                 'SUB_AFINIDAD'|| ';' ||
                 'SAL_PROCESADORA'|| ';' ||
                 'COD_RUB_ECONOMICO'|| ';' ||
                 'COD_TIP_CIERRE'|| ';' ||
                 'FRANQUEO'|| ';' ||
                 'IND_SEG_VIDA'|| ';' ||
                 'COD_EXC_CARGO'|| ';' ||
                 'LIN_ESPECIAL'|| ';' ||
                 'TAS_ESPECIAL'|| ';' ||
                 'MTO_CAR_SUSPENDIDO'|| ';' ||
                 'MTO_CAR_SUS_APLICADO'|| ';' ||
                 'COD_OFI_CLIENTE'|| ';' ||
                 'COD_OFI_OPERACION'|| ';' ||
                 'FEC_CIERRE'|| ';' ||
                 'MTO_PAG_MIN_CIERRE'|| ';' ||
                 'FEC_VTO_PAGO'|| ';' ||
                 'COD_USU_OFICIAL'|| ';' ||
                 'COD_SEG_CLIENTE';

   utl_file.put_line(v_archivo, v_registro);
   
   ---Tar_Cuentas
   BEGIN
     OPEN c_tar_cuentas;
      LOOP
        FETCH c_tar_cuentas BULK COLLECT INTO v_tar_cuentas LIMIT c_limit;
        EXIT WHEN v_tar_cuentas.COUNT = 0;
        FOR i IN 1 .. v_tar_cuentas.COUNT LOOP
           v_cont_cab  := v_cont_cab + 1;
           v_registro := p_cod_entidad|| ';' ||
                         v_tar_cuentas(i).nro_operacion|| ';' ||
                         v_tar_cuentas(i).cod_moneda|| ';' ||
                         v_tar_cuentas(i).cod_modalidad|| ';' ||
                         v_tar_cuentas(i).nom_cliente|| ';' ||
                         v_tar_cuentas(i).ape_cliente|| ';' ||
                         v_tar_cuentas(i).tipo|| ';' ||
                         v_tar_cuentas(i).nro_doc_cliente|| ';' ||
                         v_tar_cuentas(i).cod_tipo_doc_cliente|| ';' ||
                         v_tar_cuentas(i).sexo|| ';' ||
                         v_tar_cuentas(i).cli_confidencial|| ';' ||
                         v_tar_cuentas(i).cli_especial|| ';' ||
                         v_tar_cuentas(i).es_funcionario|| ';' ||
                         v_tar_cuentas(i).RELACION|| ';' ||
                         v_tar_cuentas(i).NOM_CONYUGE|| ';' ||
                         v_tar_cuentas(i).APE_CONYUGE|| ';' ||
                         v_tar_cuentas(i).NRO_DOC_CONYUGE|| ';' ||
                         v_tar_cuentas(i).COD_TIP_DOC_CONYUGE|| ';' ||
                         v_tar_cuentas(i).SEXO_CONYUGE|| ';' ||
                         v_tar_cuentas(i).DENOMINACION|| ';' ||
                         v_tar_cuentas(i).COD_MODULO|| ';' ||
                         v_tar_cuentas(i).COD_OFICINA|| ';' ||
                         v_tar_cuentas(i).LIN_CREDITO|| ';' ||
                         v_tar_cuentas(i).LIN_CUOTAS|| ';' ||
                         v_tar_cuentas(i).SAL_FACTURAR|| ';' ||
                         v_tar_cuentas(i).SAL_FACTURADO|| ';' ||
                         v_tar_cuentas(i).SAL_FINANCIADO|| ';' ||
                         v_tar_cuentas(i).SAL_ULT_EXTRACTO|| ';' ||
                         v_tar_cuentas(i).SAL_CUO_PENDIENTES|| ';' ||
                         v_tar_cuentas(i).MTO_PAG_MINIMO|| ';' ||
                         v_tar_cuentas(i).SAL_PAG_MINIMO|| ';' ||
                         v_tar_cuentas(i).MTO_MORA|| ';' ||
                         v_tar_cuentas(i).DIA_MORA|| ';' ||
                         v_tar_cuentas(i).MTO_AUTORIZACIONES|| ';' ||
                         v_tar_cuentas(i).MTO_INT_COMPRAS|| ';' ||
                         v_tar_cuentas(i).MTO_PAG_MES|| ';' ||
                         v_tar_cuentas(i).MTO_GAS_MORA|| ';' ||
                         v_tar_cuentas(i).ESTADO|| ';' ||
                         v_tar_cuentas(i).EST_ADMINISTRADORA|| ';' ||
                         v_tar_cuentas(i).FEC_SOLICITUD|| ';' ||
                         v_tar_cuentas(i).FEC_APERTURA|| ';' ||
                         v_tar_cuentas(i).FEC_ULT_PAGO|| ';' ||
                         v_tar_cuentas(i).FEC_ULT_COMPRA|| ';' ||
                         v_tar_cuentas(i).FEC_ULT_OPERACION|| ';' ||
                         v_tar_cuentas(i).FEC_ULT_EXTRACTO|| ';' ||
                         v_tar_cuentas(i).FEC_ULT_CIERRE|| ';' ||
                         v_tar_cuentas(i).FEC_VCT_ULT_CIERRE|| ';' ||
                         v_tar_cuentas(i).TIP_CIERRE|| ';' ||
                         v_tar_cuentas(i).COB_GAS_FINANCIERO|| ';' ||
                         v_tar_cuentas(i).TIP_TAS_FINANCIACION|| ';' ||
                         v_tar_cuentas(i).TIP_COM_EMISION|| ';' ||
                         v_tar_cuentas(i).TAS_FINANCIACION|| ';' ||
                         v_tar_cuentas(i).TAS_ADELANTO|| ';' ||
                         v_tar_cuentas(i).TAS_MORA|| ';' ||
                         v_tar_cuentas(i).TAS_CUOTAS|| ';' ||
                         v_tar_cuentas(i).DEB_AUTOMATICO|| ';' ||
                         v_tar_cuentas(i).TIP_COBRO|| ';' ||
                         v_tar_cuentas(i).NRO_CTA_DEBITO|| ';' ||
                         v_tar_cuentas(i).MTO_MIN_PAGO|| ';' ||
                         v_tar_cuentas(i).POR_PAG_MINIMO|| ';' ||
                         v_tar_cuentas(i).COD_USU_PROMOTOR|| ';' ||
                         v_tar_cuentas(i).MAR_MORA|| ';' ||
                         v_tar_cuentas(i).MAR_EXCEDIDO|| ';' ||
                         v_tar_cuentas(i).MAR_RECUPERADO|| ';' ||
                         v_tar_cuentas(i).MAR_BLOQUEO|| ';' ||
                         v_tar_cuentas(i).CON_COSTO|| ';' ||
                         v_tar_cuentas(i).NRO_SOLICITUD|| ';' ||
                         v_tar_cuentas(i).COD_CAUSA|| ';' ||
                         v_tar_cuentas(i).COD_CANAL|| ';' ||
                         v_tar_cuentas(i).COD_CAMPANA|| ';' ||
                         v_tar_cuentas(i).CAT_AUTOMATICA|| ';' ||
                         v_tar_cuentas(i).FEC_JUICIO|| ';' ||
                         v_tar_cuentas(i).COD_ENT_JUICIO|| ';' ||
                         v_tar_cuentas(i).MAX_ATRASO|| ';' ||
                         v_tar_cuentas(i).PRO_ATRASO|| ';' ||
                         v_tar_cuentas(i).NRO_LINEA|| ';' ||
                         v_tar_cuentas(i).EN_JUICIO|| ';' ||
                         v_tar_cuentas(i).CAT_AUT_ANTERIOR|| ';' ||
                         v_tar_cuentas(i).FEC_ACTIVACION|| ';' ||
                         v_tar_cuentas(i).FEC_CANCELACION|| ';' ||
                         v_tar_cuentas(i).TAS_EFECTIVA|| ';' ||
                         v_tar_cuentas(i).MTO_AUT_CUOTAS|| ';' ||
                         v_tar_cuentas(i).AFINIDAD|| ';' ||
                         v_tar_cuentas(i).SUB_AFINIDAD|| ';' ||
                         v_tar_cuentas(i).SAL_PROCESADORA|| ';' ||
                         v_tar_cuentas(i).COD_RUB_ECONOMICO|| ';' ||
                         v_tar_cuentas(i).COD_TIP_CIERRE|| ';' ||
                         v_tar_cuentas(i).FRANQUEO|| ';' ||
                         v_tar_cuentas(i).IND_SEG_VIDA|| ';' ||
                         v_tar_cuentas(i).COD_EXC_CARGO|| ';' ||
                         v_tar_cuentas(i).LIN_ESPECIAL|| ';' ||
                         v_tar_cuentas(i).TAS_ESPECIAL|| ';' ||
                         v_tar_cuentas(i).MTO_CAR_SUSPENDIDO|| ';' ||
                         v_tar_cuentas(i).MTO_CAR_SUS_APLICADO|| ';' ||
                         v_tar_cuentas(i).cod_ofi_cliente|| ';' ||
                         v_tar_cuentas(i).cod_ofi_operacion|| ';' ||
                         v_tar_cuentas(i).fec_cierre|| ';' ||
                         v_tar_cuentas(i).mto_pag_min_cierre|| ';' ||
                         v_tar_cuentas(i).fec_vto_pago|| ';' ||
                         v_tar_cuentas(i).cod_usu_oficial|| ';' ||
                         v_tar_cuentas(i).cod_seg_cliente;
            utl_file.put_line(v_archivo, v_registro);
       END LOOP;
     END LOOP;
     CLOSE c_tar_cuentas;
   END;
     
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
   lp_ins_log('LP_GEN_TAR_CUENTAS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
   utl_file.fclose(v_archivo);
   
   if utl_file.is_open(v_arc_tar) then
     utl_file.fclose(v_arc_tar);
   end if;

   ---tar_tarjetas
   v_nom_arc_tar := 'CR_IMP_TAR_TARJETAS_'||p_cod_entidad||'.CSV';
   v_arc_tar     := utl_file.fopen(p_directorio, v_nom_arc_tar, 'w', 32767);

   v_reg_tar := 'COD_ENTE'|| ';' ||
                'NRO_OPERACION'|| ';' ||
                'NRO_TARJETA'|| ';' ||
                'NRO_DOC_CLIENTE'|| ';' ||
                'COD_TIPO_DOC_CLIENTE'|| ';' ||
                'COD_ESTADO'|| ';' ||
                'FEC_VENCIMIENTO'|| ';' ||
                'COD_CAUSA'|| ';' ||
                'NOM_EMBOZAR'|| ';' ||
                'NOM_ENVIAR'|| ';' ||
                'VIGENTE'|| ';' ||
                'FEC_EMISION'|| ';' ||
                'FEC_SOLICITUD'|| ';' ||
                'TIP_ENVIO'|| ';' ||
                'REFERENCIA'|| ';' ||
                'NRO_PLANILLA'|| ';' ||
                'TIP_PLANILLA'|| ';' ||
                'NRO_PLA_ANTERIOR'|| ';' ||
                'FEC_ENTREGA'|| ';' ||
                'FEC_ACTIVACION'|| ';' ||
                'OBSERVACION'|| ';' ||
                'PRE_EMBOZADA'|| ';' ||
                'REL_TARJETA';
   utl_file.put_line(v_arc_tar, v_reg_tar);
   
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');  
   BEGIN
     OPEN c_tar_tarjetas;
      LOOP
        FETCH c_tar_tarjetas BULK COLLECT INTO v_tarjetas LIMIT c_limit;
        EXIT WHEN v_tarjetas.COUNT = 0;
        FOR i IN 1 .. v_tarjetas.COUNT LOOP
           v_cont_det  := v_cont_det + 1;
           v_reg_tar := p_cod_entidad|| ';' ||
                        v_tarjetas(i).nro_cuenta|| ';' ||
                        v_tarjetas(i).nro_tarjeta|| ';' ||
                        v_tarjetas(i).nro_documento|| ';' ||
                        v_tarjetas(i).cod_tip_documento|| ';' ||
                        v_tarjetas(i).cod_estado|| ';' ||
                        v_tarjetas(i).fec_vencimiento|| ';' ||
                        v_tarjetas(i).cod_causa|| ';' ||
                        v_tarjetas(i).nom_embozar|| ';' ||
                        v_tarjetas(i).nom_enviar|| ';' ||
                        v_tarjetas(i).vigente|| ';' ||
                        v_tarjetas(i).fec_emision|| ';' ||
                        v_tarjetas(i).fec_solicitud|| ';' ||
                        v_tarjetas(i).tip_envio|| ';' ||
                        v_tarjetas(i).referencia|| ';' ||
                        v_tarjetas(i).nro_planilla|| ';' ||
                        v_tarjetas(i).tip_planilla|| ';' ||
                        v_tarjetas(i).nro_pla_anterior|| ';' ||
                        v_tarjetas(i).fec_entrega|| ';' ||
                        v_tarjetas(i).fec_activacion|| ';' ||
                        v_tarjetas(i).observacion|| ';' ||
                        v_tarjetas(i).pre_embozada|| ';' ||
                        v_tarjetas(i).rel_tarjeta;
            utl_file.put_line(v_arc_tar, v_reg_tar);
        END LOOP;
     END LOOP;
     CLOSE c_tar_tarjetas;
   END;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
   lp_ins_log('LP_GEN_TAR_CUENTAS',v_hor_ini,v_hor_fin,v_nom_arc_tar,v_cont_det);
   
   utl_file.fclose(v_arc_tar);
   p_archivo := v_archivo;
END;


PROCEDURE LP_GEN_TAR_PAGO(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  
  TYPE rec_cobros IS RECORD( nro_cuenta       ta_cobros.nro_cuenta%type,
                             nro_tarjeta      ta_cobros.nro_tarjeta%type,
                             nro_cta_debito   ta_cobros.nro_cta_debito%type,
                             fec_proceso      ta_cobros.fec_proceso%type,
                             monto            ta_cobros.monto%type,
                             estado           ta_cobros.estado%type,
                             fec_valor        ta_cobros.fec_valor%type,
                             observacion      ta_cobros.observacion%type,
                             est_envio        ta_cobros.est_envio%type,
                             hora             ta_cobros.hora%type,
                             cod_usuario      ta_cobros.cod_usuario%type,
                             dia_mora         ta_cobros.dia_mora%type,
                             tip_envio        ta_cobros.tip_envio%type,
                             tipo             ta_cobros.tipo%type,
                             red_pago         ta_cobros.red_pago%type);
  
  type tof_rec_cobros is table of rec_cobros;
  v_cobros tof_rec_cobros;
  
  cursor cobros is
    select nro_cuenta,
           nro_tarjeta,
           nro_cta_debito,
           to_char(fec_proceso,'dd/mm/yyyy') fec_proceso,
           nvl(monto,0) monto,
           estado,
           to_char(fec_valor,'dd/mm/yyyy') fec_valor,
           observacion,
           est_envio,
           hora,
           cod_usuario,
           dia_mora,
           tip_envio,
           tipo,
           red_pago
      from ta_cobros a
     where a.fec_proceso >= (v_fecha - 30)
     union
     select nro_cuenta,
           nro_tarjeta,
           nro_cta_debito,
           to_char(fec_proceso,'dd/mm/yyyy') fec_proceso,
           nvl(monto,0) monto,
           estado,
           to_char(fec_valor,'dd/mm/yyyy') fec_valor,
           observacion,
           est_envio,
           hora,
           cod_usuario,
           dia_mora,
           tip_envio,
           tipo,
           red_pago
      from ta_cobros_gp a
     where a.fec_proceso >= (v_fecha - 30);

     BEGIN
       v_nom_archivo := 'CR_IMP_TAR_PAGOS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_OPERACION'|| ';' ||
                     'NRO_TARJETA'|| ';' ||
                     'NRO_CTA_DEBITO'|| ';' ||
                     'FEC_PROCESO'|| ';' ||
                     'MONTO'|| ';' ||
                     'ESTADO'|| ';' ||
                     'FEC_VALOR'|| ';' ||
                     'OBSERVACION'|| ';' ||
                     'EST_ENVIO'|| ';' ||
                     'HORA'|| ';' ||
                     'COD_USUARIO'|| ';' ||
                     'DIA_MORA'|| ';' ||
                     'TIP_ENVIO'|| ';' ||
                     'TIPO'|| ';' ||
                     'RED_PAGO';
        utl_file.put_line(v_archivo, v_registro);
        BEGIN
       OPEN cobros;
        LOOP
          FETCH cobros BULK COLLECT INTO v_cobros LIMIT c_limit;
          EXIT WHEN v_cobros.COUNT = 0;

          FOR i IN 1 .. v_cobros.COUNT LOOP
            v_cont_cab  := v_cont_cab + 1;
            v_registro := p_cod_entidad|| ';' ||
                          v_cobros(i).NRO_CUENTA|| ';' ||
                          v_cobros(i).NRO_TARJETA|| ';' ||
                          v_cobros(i).NRO_CTA_DEBITO|| ';' ||
                          v_cobros(i).FEC_PROCESO|| ';' ||
                          v_cobros(i).MONTO|| ';' ||
                          v_cobros(i).ESTADO|| ';' ||
                          v_cobros(i).FEC_VALOR|| ';' ||
                          v_cobros(i).OBSERVACION|| ';' ||
                          v_cobros(i).EST_ENVIO|| ';' ||
                          v_cobros(i).HORA|| ';' ||
                          v_cobros(i).COD_USUARIO|| ';' ||
                          v_cobros(i).DIA_MORA|| ';' ||
                          v_cobros(i).TIP_ENVIO|| ';' ||
                          v_cobros(i).TIPO|| ';' ||
                          v_cobros(i).RED_PAGO;
             utl_file.put_line(v_archivo, v_registro);
         END LOOP;
        END LOOP;
        CLOSE cobros;
       END;  
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_TAR_PAGO',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

   PROCEDURE LP_GEN_PRE_PREVISIONES(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor cobros is
    select d.cod_tip_documento,
           d.nro_documento,
           to_char(a.fecha,'dd/mm/yyyy') fecha,
           a.nro_cuenta,
           nvl(a.monto,0) monto,
           nvl(a.sal_capital,0) sal_capital,
           nvl(a.dev_no_cobrado,0) dev_no_cobrado,
           a.porcentaje,
           nvl(a.tot_gar_computables,0) tot_gar_computables,
           nvl(a.tot_pri_prevision,0) tot_pri_prevision,
           nvl(a.tot_cap_pri_prevision,0) tot_cap_pri_prevision,
           nvl(a.tot_cap_seg_prevision,0) tot_cap_seg_prevision,
           nvl(a.tot_int_pri_prevision,0) tot_int_pri_prevision,
           nvl(a.tot_int_seg_prevision,0) tot_int_seg_prevision,
           nvl(a.mto_pre_total,0) mto_pre_total
      from pr_previsiones   a,
           pr_cta_prestamos b,
           ge_cta_clientes  c,
           ba_personas      d
     where b.nro_cuenta = a.nro_cuenta
       and c.nro_cuenta = a.nro_cuenta
       and c.relacion = 'P'
       and a.fecha = v_fecha
       and d.cod_persona = c.cod_persona;

     BEGIN
       v_nom_archivo := 'CR_IMP_PRE_PREVISIONES_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_OPERACION' || ';' ||
                     'COD_TIPO_DOC_CLIENTE'|| ';' ||
                     'NRO_DOC_CLIENTE'|| ';' ||
                     'FECHA' || ';' ||
                     'MONTO' || ';' ||
                     'SAL_CAPITAL' || ';' ||
                     'DEV_NO_COBRADO' || ';' ||
                     'PORCENTAJE' || ';' ||
                     'TOT_GAR_COMPUTABLES' || ';' ||
                     'TOT_PRI_PREVISION' || ';' ||
                     'TOT_CAP_PRI_PREVISION' || ';' ||
                     'TOT_CAP_SEG_PREVISION' || ';' ||
                     'TOT_INT_PRI_PREVISION' || ';' ||
                     'TOT_INT_SEG_PREVISION' || ';' ||
                     'MTO_PRE_TOTAL';
        utl_file.put_line(v_archivo, v_registro);
        for c in cobros loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_cuenta|| ';' ||
                        c.cod_tip_documento|| ';' ||
                        c.nro_documento|| ';' ||
                        c.fecha|| ';' ||
                        c.monto|| ';' ||
                        c.sal_capital|| ';' ||
                        c.dev_no_cobrado|| ';' ||
                        c.porcentaje|| ';' ||
                        c.tot_gar_computables|| ';' ||
                        c.tot_pri_prevision|| ';' ||
                        c.tot_cap_pri_prevision|| ';' ||
                        c.tot_cap_seg_prevision|| ';' ||
                        c.tot_int_pri_prevision|| ';' ||
                        c.tot_int_seg_prevision|| ';' ||
                        c.mto_pre_total;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_PRE_PREVISIONES',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_GARANTIAS(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_garantias is
    select b.cod_tip_documento,
           b.nro_documento,
           a.nro_garantia,
           a.cod_garantia,
           a.cod_moneda,
           nvl(a.valor,0) valor,
           nvl(a.val_tasacion,0) val_tasacion,
           to_char(a.fec_ult_tasacion,'dd/mm/yyyy') fec_ult_tasacion,
           to_char(a.fec_inicio,'dd/mm/yyyy') fec_inicio,
           to_char(a.fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
           a.cod_ent_escribania,
           a.cod_ent_seguro,
           a.tipo,
           a.estado,
           a.cod_persona,
           fug_eli_car_especiales(a.observacion) observacion,
           a.cod_mon_tasacion,
           nvl(a.mto_aplicado,0) mto_aplicado,
           a.est_tesoreria,
           a.est_verificacion,
           to_char(a.fec_ent_tesoreria,'dd/mm/yyyy') fec_ent_tesoreria,
           to_char(a.fec_sal_tesoreria,'dd/mm/yyyy') fec_sal_tesoreria,
           a.cod_usu_entregado,
           a.cod_cau_salida,
           nvl(a.mto_apl_valor,0) mto_apl_valor,
           a.ind_uti_tercero,
           a.situacion,
           a.cod_oficina,
           a.nro_escritura,
           to_char(a.fec_ult_utilizacion,'dd/mm/yyyy') fec_ult_utilizacion,
           fug_eli_car_especiales(a.observacion_his) observacion_his,
           a.nro_referencia,
           a.perfeccionada,
           a.rango,
           to_char(a.fec_confirmacion,'dd/mm/yyyy') fec_confirmacion
      from pr_garantias a, ba_personas b
     where b.cod_persona = a.cod_persona;

     BEGIN
       v_nom_archivo := 'CR_IMP_GARANTIAS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'COD_TIPO_DOC_CLIENTE'|| ';' ||
                     'NRO_DOC_CLIENTE'|| ';' ||
                     'NRO_GARANTIA' || ';' ||
                     'COD_GARANTIA' || ';' ||
                     'COD_MONEDA' || ';' ||
                     'VALOR' || ';' ||
                     'VAL_TASACION' || ';' ||
                     'FEC_ULT_TASACION' || ';' ||
                     'FEC_INICIO' || ';' ||
                     'FEC_VENCIMIENTO' || ';' ||
                     'COD_ENT_ESCRIBANIA' || ';' ||
                     'COD_ENT_SEGURO' || ';' ||
                     'TIPO' || ';' ||
                     'ESTADO' || ';' ||
                     'COD_PERSONA' || ';' ||
                     'OBSERVACION' || ';' ||
                     'COD_MON_TASACION' || ';' ||
                     'MTO_APLICADO' || ';' ||
                     'EST_TESORERIA' || ';' ||
                     'EST_VERIFICACION' || ';' ||
                     'FEC_ENT_TESORERIA' || ';' ||
                     'FEC_SAL_TESORERIA' || ';' ||
                     'COD_USU_ENTREGADO' || ';' ||
                     'COD_CAU_SALIDA' || ';' ||
                     'MTO_APL_VALOR' || ';' ||
                     'IND_UTI_TERCERO' || ';' ||
                     'SITUACION' || ';' ||
                     'COD_OFICINA' || ';' ||
                     'NRO_ESCRITURA' || ';' ||
                     'FEC_ULT_UTILIZACION' || ';' ||
                     'OBSERVACION_HIS' || ';' ||
                     'NRO_REFERENCIA' || ';' ||
                     'PERFECCIONADA' || ';' ||
                     'RANGO' || ';' ||
                     'FEC_CONFIRMACION';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.cod_tip_documento|| ';' ||
                        c.nro_documento|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.cod_garantia|| ';' ||
                        c.cod_moneda|| ';' ||
                        c.valor|| ';' ||
                        c.val_tasacion|| ';' ||
                        c.fec_ult_tasacion|| ';' ||
                        c.fec_inicio|| ';' ||
                        c.fec_vencimiento|| ';' ||
                        c.cod_ent_escribania|| ';' ||
                        c.cod_ent_seguro|| ';' ||
                        c.tipo|| ';' ||
                        c.estado|| ';' ||
                        c.cod_persona|| ';' ||
                        c.observacion|| ';' ||
                        c.cod_mon_tasacion|| ';' ||
                        c.mto_aplicado|| ';' ||
                        c.est_tesoreria|| ';' ||
                        c.est_verificacion|| ';' ||
                        c.fec_ent_tesoreria|| ';' ||
                        c.fec_sal_tesoreria|| ';' ||
                        c.cod_usu_entregado|| ';' ||
                        c.cod_cau_salida|| ';' ||
                        c.mto_apl_valor|| ';' ||
                        c.ind_uti_tercero|| ';' ||
                        c.situacion|| ';' ||
                        c.cod_oficina|| ';' ||
                        c.nro_escritura|| ';' ||
                        c.fec_ult_utilizacion|| ';' ||
                        c.observacion_his|| ';' ||
                        c.nro_referencia|| ';' ||
                        c.perfeccionada|| ';' ||
                        c.rango|| ';' ||
                        c.fec_confirmacion;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_GARANTIAS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_CTA_GARANTIAS(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select c.cod_tip_documento,
           c.nro_documento,
           a.nro_cuenta,
           a.nro_garantia,
           a.cod_garantia,
           trim(d.pri_nombre) || ' ' || trim(d.seg_nombre) nom_codeudor,
           trim(d.pri_apellido) || ' ' || trim(d.seg_apellido) ape_codeudor,
           e.nro_documento nro_doc_codeudor,
           e.cod_tip_documento cod_tipo_doc_codeudor,
           d.cod_sexo,
           to_char(d.fec_nacimiento,'DD/MM/YYYY') fec_nacimiento,
           e.cod_rub_primario,
           e.cod_rub_secundario,
           e.cod_rub_terciario,
           nvl(a.mto_aplicado,0) mto_aplicado,
           nvl(a.mto_con_computable,0) mto_con_computable,
           nvl(a.mto_apl_computable,0) mto_apl_computable,
           nvl(a.mto_con_nocomputable,0) mto_con_nocomputable,
           a.porcentaje
      from pr_cta_garantias a, ge_cta_clientes b, ba_personas c,
           ba_per_fisicas d, ba_personas e, pr_cta_prestamos f
     where a.nro_cuenta = b.nro_cuenta
       and b.relacion = 'P'
       and f.nro_cuenta = a.nro_cuenta
       and f.estado <> 'N'
       and c.cod_persona = b.cod_persona
       and a.nro_garantia = d.cod_persona(+)
       and e.cod_persona(+) = d.cod_persona
   union all
   select c.cod_tip_documento,
           c.nro_documento,
           a.nro_cuenta,
           a.nro_garantia,
           a.cod_garantia,
           d.raz_social nom_codeudor,
           d.nom_comercial ape_codeudor,
           e.nro_documento nro_doc_codeudor,
           e.cod_tip_documento cod_tipo_doc_codeudor,
           null,
           to_char(d.fec_apertura,'DD/MM/YYYY') fec_nacimiento,
           e.cod_rub_primario,
           e.cod_rub_secundario,
           e.cod_rub_terciario,
           nvl(a.mto_aplicado,0) mto_aplicado,
           nvl(a.mto_con_computable,0) mto_con_computable,
           nvl(a.mto_apl_computable,0) mto_apl_computable,
           nvl(a.mto_con_nocomputable,0) mto_con_nocomputable,
           a.porcentaje
      from pr_cta_garantias a, ge_cta_clientes b, ba_personas c,
           ba_per_juridicas d, ba_personas e, pr_cta_prestamos f
     where a.nro_cuenta = b.nro_cuenta
       and b.relacion = 'P'
       and f.nro_cuenta = a.nro_cuenta
       and f.estado <> 'N'
       and c.cod_persona = b.cod_persona
       and a.nro_garantia = d.cod_persona
       and e.cod_persona = d.cod_persona;

     BEGIN
       v_nom_archivo := 'CR_IMP_CTA_GARANTIAS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'COD_TIP_DOCUMENTO'|| ';' ||
                     'NRO_DOCUMENTO'|| ';' ||
                     'NRO_OPERACION'|| ';' ||
                     'NRO_GARANTIA'|| ';' ||
                     'COD_GARANTIA'|| ';' ||
                     'NOM_CODEUDOR'|| ';' ||
                     'APE_CODEUDOR'|| ';' ||
                     'NRO_DOC_CODEUDOR'|| ';' ||
                     'COD_TIPO_DOC_CODEUDOR'|| ';' ||
                     'SEXO'|| ';' ||
                     'FEC_NACIMIENTO'|| ';' ||
                     'COD_RUB_PRIMARIO'|| ';' ||
                     'COD_RUB_SECUNDARIO'|| ';' ||
                     'COD_RUB_TERCIARIO'|| ';' ||
                     'MTO_APLICADO'|| ';' ||
                     'MTO_CON_COMPUTABLE'|| ';' ||
                     'MTO_APL_COMPUTABLE'|| ';' ||
                     'MTO_CON_NOCOMPUTABLE'|| ';' ||
                     'PORCENTAJE';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.cod_tip_documento|| ';' ||
                        c.nro_documento|| ';' ||
                        c.nro_cuenta|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.cod_garantia|| ';' ||
                        c.nom_codeudor|| ';' ||
                        c.ape_codeudor|| ';' ||
                        c.nro_doc_codeudor|| ';' ||
                        c.cod_tipo_doc_codeudor|| ';' ||
                        c.cod_sexo|| ';' ||
                        c.fec_nacimiento|| ';' ||
                        c.cod_rub_primario|| ';' ||
                        c.cod_rub_secundario|| ';' ||
                        c.cod_rub_terciario|| ';' ||
                        c.mto_aplicado|| ';' ||
                        c.mto_con_computable|| ';' ||
                        c.mto_apl_computable|| ';' ||
                        c.mto_con_nocomputable|| ';' ||
                        c.porcentaje;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_CTA_GARANTIAS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_GAR_HIPOTECAS(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select a.nro_garantia,
           a.nro_finca,
           a.cod_distrito,
           a.cta_catastral,
           fug_eli_car_especiales(a.direccion) direccion,
           nvl(a.val_edilicio,0) val_edilicio,
           nvl(a.val_terreno,0) val_terreno,
           to_char(a.fec_ult_tasacion,'dd/mm/yyyy') fec_ult_tasacion,
           to_char(a.fec_inicio,'dd/mm/yyyy') fec_inicio,
           to_char(a.fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
           a.cod_ent_seguro,
           a.nro_poliza,
           to_char(a.fec_vto_seguro,'dd/mm/yyyy') fec_vto_seguro,
           a.serie,
           a.nro_inscripcion,
           a.nro_folio,
           to_char(a.fec_inscripcion,'dd/mm/yyyy') fec_inscripcion,
           a.val_vta_rapida,
           a.val_seguro,
           a.cod_ent_tasador,
           to_char(a.fec_ini_seguro,'dd/mm/yyyy') fec_ini_seguro,
           a.cod_ent_fiduciaria
      from pr_gar_hipotecarias a;

     BEGIN
       v_nom_archivo := 'CR_IMP_GAR_HIPOTECARIAS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_GARANTIA' || ';' ||
                     'NRO_FINCA' || ';' ||
                     'COD_DISTRITO' || ';' ||
                     'CTA_CATASTRAL' || ';' ||
                     'DIRECCION' || ';' ||
                     'VAL_EDILICIO' || ';' ||
                     'VAL_TERRENO' || ';' ||
                     'FEC_ULT_TASACION' || ';' ||
                     'FEC_INICIO' || ';' ||
                     'FEC_VENCIMIENTO' || ';' ||
                     'COD_ENT_SEGURO' || ';' ||
                     'NRO_POLIZA' || ';' ||
                     'FEC_VTO_SEGURO' || ';' ||
                     'SERIE' || ';' ||
                     'NRO_INSCRIPCION' || ';' ||
                     'NRO_FOLIO' || ';' ||
                     'FEC_INSCRIPCION' || ';' ||
                     'VAL_VTA_RAPIDA' || ';' ||
                     'VAL_SEGURO' || ';' ||
                     'COD_ENT_TASADOR' || ';' ||
                     'FEC_INI_SEGURO' || ';' ||
                     'COD_ENT_FIDUCIARIA';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.nro_finca|| ';' ||
                        c.cod_distrito|| ';' ||
                        c.cta_catastral|| ';' ||
                        c.direccion|| ';' ||
                        c.val_edilicio|| ';' ||
                        c.val_terreno|| ';' ||
                        c.fec_ult_tasacion|| ';' ||
                        c.fec_inicio|| ';' ||
                        c.fec_vencimiento|| ';' ||
                        c.cod_ent_seguro|| ';' ||
                        c.nro_poliza|| ';' ||
                        c.fec_vto_seguro|| ';' ||
                        c.serie|| ';' ||
                        c.nro_inscripcion|| ';' ||
                        c.nro_folio|| ';' ||
                        c.fec_inscripcion|| ';' ||
                        c.val_vta_rapida|| ';' ||
                        c.val_seguro|| ';' ||
                        c.cod_ent_tasador|| ';' ||
                        c.fec_ini_seguro|| ';' ||
                        c.cod_ent_fiduciaria;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_GAR_HIPOTECAS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_GAR_AVALES(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select a.nro_garantia,
           a.nro_referencia,
           to_char(a.fec_inicio,'dd/mm/yyyy') fec_inicio,
           to_char(a.fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
           nvl(a.monto,0) monto,
           a.beneficiario,
           a.cod_ent_emisor,
           fug_eli_car_especiales(a.observacion) observacion
      from pr_gar_avales a;

     BEGIN
       v_nom_archivo := 'CR_IMP_GAR_AVALES_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_GARANTIA' || ';' ||
                     'NRO_REFERENCIA' || ';' ||
                     'FEC_INICIO' || ';' ||
                     'FEC_VENCIMIENTO' || ';' ||
                     'MONTO' || ';' ||
                     'BENEFICIARIO' || ';' ||
                     'COD_ENT_EMISOR' || ';' ||
                     'OBSERVACION';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.nro_referencia|| ';' ||
                        c.fec_inicio|| ';' ||
                        c.fec_vencimiento|| ';' ||
                        c.monto|| ';' ||
                        c.beneficiario|| ';' ||
                        c.cod_ent_emisor|| ';' ||
                        c.observacion;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_GAR_AVALES',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_GAR_CASH(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select a.nro_garantia,
           a.nro_cta_referencia,
           a.cod_emisor,
           a.cod_cas_tipo,
           a.serie,
           a.nro_certificado,
           a.cod_moneda,
           nvl(a.monto,0) monto,
           fug_eli_car_especiales(a.observacion) observacion,
           a.beneficiario,
           to_char(a.fec_inicio,'dd/mm/yyyy') fec_inicio,
           to_char(a.fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
           fug_eli_car_especiales(a.observacion_his) observacion_his
      from pr_gar_cash a;

     BEGIN
       v_nom_archivo := 'CR_IMP_GAR_CASH_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_GARANTIA' || ';' ||
                     'NRO_CTA_REFERENCIA' || ';' ||
                     'COD_EMISOR' || ';' ||
                     'COD_CAS_TIPO' || ';' ||
                     'SERIE' || ';' ||
                     'NRO_CERTIFICADO' || ';' ||
                     'COD_MONEDA' || ';' ||
                     'MONTO' || ';' ||
                     'OBSERVACION' || ';' ||
                     'BENEFICIARIO' || ';' ||
                     'FEC_INICIO' || ';' ||
                     'FEC_VENCIMIENTO' || ';' ||
                     'OBSERVACION_HIS';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.nro_cta_referencia|| ';' ||
                        c.cod_emisor|| ';' ||
                        c.cod_cas_tipo|| ';' ||
                        c.serie|| ';' ||
                        c.nro_certificado|| ';' ||
                        c.cod_moneda|| ';' ||
                        c.monto|| ';' ||
                        c.observacion|| ';' ||
                        c.beneficiario|| ';' ||
                        c.fec_inicio|| ';' ||
                        c.fec_vencimiento|| ';' ||
                        c.observacion_his;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_GAR_CASH',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_GAR_DOCUMENTOS(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select a.nro_garantia,
           a.tip_documento,
           to_char(a.fec_emision,'dd/mm/yyyy') fec_emision,
           to_char(a.fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
           nvl(a.monto,0) monto,
           a.beneficiario,
           a.cod_ent_emisor,
           a.librador,
           fug_eli_car_especiales(a.observacion) observacion,
           a.nro_documento,
           a.nro_secuencia,
           fug_eli_car_especiales(a.observacion_his) observacion_his,
           a.serie,
           a.renegociado,
           a.cta_libradora,
           to_char(a.fec_fin_renegociacion,'dd/mm/yyyy') fec_fin_renegociacion
      from pr_gar_documentos a;

     BEGIN
       v_nom_archivo := 'CR_IMP_GAR_DOCUMENTOS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_GARANTIA'|| ';' ||
                     'TIP_DOCUMENTO'|| ';' ||
                     'FEC_EMISION'|| ';' ||
                     'FEC_VENCIMIENTO'|| ';' ||
                     'MONTO'|| ';' ||
                     'BENEFICIARIO'|| ';' ||
                     'COD_ENT_EMISOR'|| ';' ||
                     'LIBRADOR'|| ';' ||
                     'OBSERVACION'|| ';' ||
                     'NRO_DOCUMENTO'|| ';' ||
                     'NRO_SECUENCIA'|| ';' ||
                     'OBSERVACION_HIS'|| ';' ||
                     'SERIE'|| ';' ||
                     'RENEGOCIADO'|| ';' ||
                     'CTA_LIBRADORA'|| ';' ||
                     'FEC_FIN_RENEGOCIACION';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.tip_documento|| ';' ||
                        c.fec_emision|| ';' ||
                        c.fec_vencimiento|| ';' ||
                        c.monto|| ';' ||
                        c.beneficiario|| ';' ||
                        c.cod_ent_emisor|| ';' ||
                        c.librador|| ';' ||
                        c.observacion|| ';' ||
                        c.nro_documento|| ';' ||
                        c.nro_secuencia|| ';' ||
                        c.observacion_his|| ';' ||
                        c.serie|| ';' ||
                        c.renegociado|| ';' ||
                        c.cta_libradora|| ';' ||
                        c.fec_fin_renegociacion;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_GAR_DOCUMENTOS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;


PROCEDURE LP_GEN_GAR_FIDEICOMISO(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select a.nro_garantia,
           a.nro_finca,
           a.cod_distrito,
           a.cta_catastral,
           a.direccion,
           nvl(a.val_edilicio,0) val_edilicio,
           nvl(a.val_terreno,0) val_terreno,
           to_char(a.fec_ult_tasacion,'dd/mm/yyyy') fec_ult_tasacion,
           to_char(a.fec_inicio,'dd/mm/yyyy') fec_inicio,
           to_char(a.fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
           a.cod_ent_seguro,
           a.nro_poliza,
           to_char(a.fec_vto_seguro,'dd/mm/yyyy') fec_vto_seguro,
           a.serie,
           a.nro_inscripcion,
           a.nro_folio,
           to_char(a.fec_inscripcion,'dd/mm/yyyy') fec_inscripcion,
           a.val_vta_rapida,
           a.val_seguro,
           a.cod_ent_tasador,
           to_char(a.fec_ini_seguro,'dd/mm/yyyy') fec_ini_seguro,
           a.cod_ent_fiduciaria
      from pr_gar_fideicomiso a;

     BEGIN
       v_nom_archivo := 'CR_IMP_GAR_FIDEICOMISO_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_GARANTIA'|| ';' ||
                     'NRO_FINCA'|| ';' ||
                     'COD_DISTRITO'|| ';' ||
                     'CTA_CATASTRAL'|| ';' ||
                     'DIRECCION'|| ';' ||
                     'VAL_EDILICIO'|| ';' ||
                     'VAL_TERRENO'|| ';' ||
                     'FEC_ULT_TASACION'|| ';' ||
                     'FEC_INICIO'|| ';' ||
                     'FEC_VENCIMIENTO'|| ';' ||
                     'COD_ENT_SEGURO'|| ';' ||
                     'NRO_POLIZA'|| ';' ||
                     'FEC_VTO_SEGURO'|| ';' ||
                     'SERIE'|| ';' ||
                     'NRO_INSCRIPCION'|| ';' ||
                     'NRO_FOLIO'|| ';' ||
                     'FEC_INSCRIPCION'|| ';' ||
                     'VAL_VTA_RAPIDA'|| ';' ||
                     'VAL_SEGURO'|| ';' ||
                     'COD_ENT_TASADOR'|| ';' ||
                     'FEC_INI_SEGURO'|| ';' ||
                     'COD_ENT_FIDUCIARIA';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.nro_finca|| ';' ||
                        c.cod_distrito|| ';' ||
                        c.cta_catastral|| ';' ||
                        c.direccion|| ';' ||
                        c.val_edilicio|| ';' ||
                        c.val_terreno|| ';' ||
                        c.fec_ult_tasacion|| ';' ||
                        c.fec_inicio|| ';' ||
                        c.fec_vencimiento|| ';' ||
                        c.cod_ent_seguro|| ';' ||
                        c.nro_poliza|| ';' ||
                        c.fec_vto_seguro|| ';' ||
                        c.serie|| ';' ||
                        c.nro_inscripcion|| ';' ||
                        c.nro_folio|| ';' ||
                        c.fec_inscripcion|| ';' ||
                        c.val_vta_rapida|| ';' ||
                        c.val_seguro|| ';' ||
                        c.cod_ent_tasador|| ';' ||
                        c.fec_ini_seguro|| ';' ||
                        c.cod_ent_fiduciaria;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_GAR_FIDEICOMISO',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_GAR_STANDBYS(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select a.nro_garantia,
           a.nro_referencia,
           to_char(a.fec_inicio,'dd/mm/yyyy') fec_inicio,
           to_char(a.fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
           nvl(a.monto,0) monto,
           a.beneficiario,
           a.cod_ent_emisor,
           fug_eli_car_especiales(a.observacion) observacion,
           fug_eli_car_especiales(a.observacion_his) observacion_his
      from pr_gar_standbys a;

     BEGIN
       v_nom_archivo := 'CR_IMP_GAR_STANDBYS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_GARANTIA' || ';' ||
                     'NRO_REFERENCIA' || ';' ||
                     'FEC_INICIO' || ';' ||
                     'FEC_VENCIMIENTO' || ';' ||
                     'MONTO' || ';' ||
                     'BENEFICIARIO' || ';' ||
                     'COD_ENT_EMISOR' || ';' ||
                     'OBSERVACION' || ';' ||
                     'OBSERVACION_HIS';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.nro_referencia|| ';' ||
                        c.fec_inicio|| ';' ||
                        c.fec_vencimiento|| ';' ||
                        c.monto|| ';' ||
                        c.beneficiario|| ';' ||
                        c.cod_ent_emisor|| ';' ||
                        c.observacion|| ';' ||
                        c.observacion_his;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_GAR_STANDBYS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_GAR_VEHICULOS(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select a.nro_garantia,
           a.nro_contrato,
           a.cod_marca,
           a.modelo,
           a.ano,
           a.nro_motor,
           a.nro_chasis,
           a.nro_chapa,
           a.nro_cedula,
           to_char(a.fec_inscripcion,'dd/mm/yyyy') fec_inscripcion,
           a.cod_ent_seguro,
           a.nro_poliza,
           to_char(a.fec_vto_seguro,'dd/mm/yyyy') fec_vto_seguro,
           a.tip_prenda,
           a.cod_ent_tasador,
           nvl(a.val_tasacion,0) val_tasacion,
           to_char(a.fec_inicio,'dd/mm/yyyy') fec_inicio,
           to_char(a.fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
           a.movil,
           nvl(a.val_seguro,0) val_seguro,
           nvl(a.val_vta_rapida,0) val_vta_rapida,
           a.nro_inscripcion,
           a.nro_folio,
           to_char(a.fec_ini_seguro,'dd/mm/yyyy') fec_ini_seguro
      from pr_gar_vehiculos a;

     BEGIN
       v_nom_archivo := 'CR_IMP_GAR_VEHICULOS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_GARANTIA' || ';' ||
                     'NRO_CONTRATO' || ';' ||
                     'COD_MARCA' || ';' ||
                     'MODELO' || ';' ||
                     'ANO' || ';' ||
                     'NRO_MOTOR' || ';' ||
                     'NRO_CHASIS' || ';' ||
                     'NRO_CHAPA' || ';' ||
                     'NRO_CEDULA' || ';' ||
                     'FEC_INSCRIPCION' || ';' ||
                     'COD_ENT_SEGURO' || ';' ||
                     'NRO_POLIZA' || ';' ||
                     'FEC_VTO_SEGURO' || ';' ||
                     'TIP_PRENDA' || ';' ||
                     'COD_ENT_TASADOR' || ';' ||
                     'VAL_TASACION' || ';' ||
                     'FEC_INICIO' || ';' ||
                     'FEC_VENCIMIENTO' || ';' ||
                     'MOVIL' || ';' ||
                     'VAL_SEGURO' || ';' ||
                     'VAL_VTA_RAPIDA' || ';' ||
                     'NRO_INSCRIPCION' || ';' ||
                     'NRO_FOLIO' || ';' ||
                     'FEC_INI_SEGURO';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.nro_contrato|| ';' ||
                        c.cod_marca|| ';' ||
                        c.modelo|| ';' ||
                        c.ano|| ';' ||
                        c.nro_motor|| ';' ||
                        c.nro_chasis|| ';' ||
                        c.nro_chapa|| ';' ||
                        c.nro_cedula|| ';' ||
                        c.fec_inscripcion|| ';' ||
                        c.cod_ent_seguro|| ';' ||
                        c.nro_poliza|| ';' ||
                        c.fec_vto_seguro|| ';' ||
                        c.tip_prenda|| ';' ||
                        c.cod_ent_tasador|| ';' ||
                        c.val_tasacion|| ';' ||
                        c.fec_inicio|| ';' ||
                        c.fec_vencimiento|| ';' ||
                        c.movil|| ';' ||
                        c.val_seguro|| ';' ||
                        c.val_vta_rapida|| ';' ||
                        c.nro_inscripcion|| ';' ||
                        c.nro_folio|| ';' ||
                        c.fec_ini_seguro;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_GAR_VEHICULOS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_GAR_WARRANTS(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select a.nro_garantia,
           a.nro_warrants,
           a.cla_mercaderia,
           nvl(a.val_unitario,0) val_unitario,
           a.marca,
           a.bulto,
           a.cantidad,
           a.peso,
           a.cod_ent_deposito,
           to_char(a.fec_inicio,'dd/mm/yyyy') fec_inicio,
           to_char(a.fec_vencimiento,'dd/mm/yyyy') fec_vencimiento,
           a.uni_medida,
           a.cod_ent_seguro,
           a.nro_poliza,
           to_char(a.fec_vto_seguro,'dd/mm/yyyy') fec_vto_seguro,
           to_char(a.fec_ini_seguro,'dd/mm/yyyy') fec_ini_seguro
      from pr_gar_warrants a;

     BEGIN
       v_nom_archivo := 'CR_IMP_GAR_WARRANTS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_GARANTIA' || ';' ||
                     'NRO_WARRANTS' || ';' ||
                     'CLA_MERCADERIA' || ';' ||
                     'VAL_UNITARIO' || ';' ||
                     'MARCA' || ';' ||
                     'BULTO' || ';' ||
                     'CANTIDAD' || ';' ||
                     'PESO' || ';' ||
                     'COD_ENT_DEPOSITO' || ';' ||
                     'FEC_INICIO' || ';' ||
                     'FEC_VENCIMIENTO' || ';' ||
                     'UNI_MEDIDA' || ';' ||
                     'COD_ENT_SEGURO' || ';' ||
                     'NRO_POLIZA' || ';' ||
                     'FEC_VTO_SEGURO' || ';' ||
                     'FEC_INI_SEGURO';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_garantia|| ';' ||
                        c.nro_warrants|| ';' ||
                        c.cla_mercaderia|| ';' ||
                        c.val_unitario|| ';' ||
                        c.marca|| ';' ||
                        c.bulto|| ';' ||
                        c.cantidad|| ';' ||
                        c.peso|| ';' ||
                        c.cod_ent_deposito|| ';' ||
                        c.fec_inicio|| ';' ||
                        c.fec_vencimiento|| ';' ||
                        c.uni_medida|| ';' ||
                        c.cod_ent_seguro|| ';' ||
                        c.nro_poliza|| ';' ||
                        c.fec_vto_seguro|| ';' ||
                        c.fec_ini_seguro;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_GAR_WARRANTS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_CTA_CLA_OPERACIONES(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select c.cod_tip_documento,
           c.nro_documento,
           a.nro_cuenta nro_operacion,
           a.cod_modulo,
           a.cod_modalidad,
           a.cod_estado,
           nvl(a.tot_deu_real,0) tot_deu_real,
           nvl(a.tot_deu_contingente,0) tot_deu_contingente,
           nvl(a.dev_no_cobrado,0) dev_no_cobrado,
           a.cat_automatica,
           a.dia_atraso,
           a.cod_moneda,
           nvl(a.tot_gar_computables,0) tot_gar_computables,
           a.cod_oficina,
           a.tipo,
           nvl(a.tot_prevision,0) tot_prevision,
           nvl(a.mto_original,0) mto_original,
           a.tip_destino,
           a.cod_sec_credito,
           a.cat_renovaciones,
           a.cat_ren_anterior,
           a.lib_prevision,
           nvl(a.tot_pri_prevision,0) tot_pri_prevision,
           a.cod_rub_economico,
           nvl(a.tot_cap_pri_prevision,0) tot_cap_pri_prevision,
           nvl(a.tot_cap_seg_prevision,0) tot_cap_seg_prevision,
           nvl(a.tot_int_pri_prevision,0) tot_int_pri_prevision,
           nvl(a.tot_int_seg_prevision,0) tot_int_seg_prevision,
           nvl(a.mto_pre_total,0) mto_pre_total,
           a.cat_pre_diferida,
           a.cat_prevision,
           nvl(a.tot_seg_prevision,0) tot_seg_prevision,
           nvl(a.tot_gar_aplicada,0) tot_gar_aplicada,
           nvl(a.tot_rie_no_cubierto,0) tot_rie_no_cubierto,
           d.cat_sistema cli_cat_sistema,
           d.cat_automatica cli_cat_automatica,
           d.cat_subjetiva cli_cat_subjetiva,
           d.cat_riesgo cli_cat_riesgo
      from ge_cla_operaciones a, pr_cta_prestamos b,
           ba_personas c, ge_clientes d
     where b.nro_cuenta = a.nro_cuenta
       and c.cod_persona = a.cod_persona
       and d.cod_persona = a.cod_persona
       and (b.estado <> 'N' or (b.estado = 'N' and b.fec_modificacion >= (v_fecha-30)))
    order by 1,2,3,4;

     BEGIN
       v_nom_archivo := 'CR_IMP_CTA_CLA_OPERACIONES_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'COD_TIPO_DOC_CLIENTE'|| ';' ||
                     'NRO_DOC_CLIENTE'|| ';' ||
                     'NRO_OPERACION'|| ';' ||
                     'COD_MODULO'|| ';' ||
                     'COD_MODALIDAD'|| ';' ||
                     'COD_ESTADO'|| ';' ||
                     'TOT_DEU_REAL'|| ';' ||
                     'TOT_DEU_CONTINGENTE'|| ';' ||
                     'DEV_NO_COBRADO'|| ';' ||
                     'CAT_AUTOMATICA'|| ';' ||
                     'DIA_ATRASO'|| ';' ||
                     'COD_MONEDA'|| ';' ||
                     'TOT_GAR_COMPUTABLES'|| ';' ||
                     'COD_OFICINA'|| ';' ||
                     'TIPO'|| ';' ||
                     'TOT_PREVISION'|| ';' ||
                     'MTO_ORIGINAL'|| ';' ||
                     'TIP_DESTINO'|| ';' ||
                     'COD_SEC_CREDITO'|| ';' ||
                     'CAT_RENOVACIONES'|| ';' ||
                     'CAT_REN_ANTERIOR'|| ';' ||
                     'LIB_PREVISION'|| ';' ||
                     'TOT_PRI_PREVISION'|| ';' ||
                     'COD_RUB_ECONOMICO'|| ';' ||
                     'TOT_CAP_PRI_PREVISION'|| ';' ||
                     'TOT_CAP_SEG_PREVISION'|| ';' ||
                     'TOT_INT_PRI_PREVISION'|| ';' ||
                     'TOT_INT_SEG_PREVISION'|| ';' ||
                     'MTO_PRE_TOTAL'|| ';' ||
                     'CAT_PRE_DIFERIDA'|| ';' ||
                     'CAT_PREVISION'|| ';' ||
                     'TOT_SEG_PREVISION'|| ';' ||
                     'TOT_GAR_APLICADA'|| ';' ||
                     'TOT_RIE_NO_CUBIERTO'|| ';' ||
                     'CLI_CAT_SISTEMA'|| ';' ||
                     'CLI_CAT_AUTOMATICA '|| ';' ||
                     'CLI_CAT_SUBJETIVA'|| ';' ||
                     'CLI_CAT_RIESGO';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.cod_tip_documento|| ';' ||
                        c.nro_documento|| ';' ||
                        c.nro_operacion|| ';' ||
                        c.cod_modulo|| ';' ||
                        c.cod_modalidad|| ';' ||
                        c.cod_estado|| ';' ||
                        c.tot_deu_real|| ';' ||
                        c.tot_deu_contingente|| ';' ||
                        c.dev_no_cobrado|| ';' ||
                        c.cat_automatica|| ';' ||
                        c.dia_atraso|| ';' ||
                        c.cod_moneda|| ';' ||
                        c.tot_gar_computables|| ';' ||
                        c.cod_oficina|| ';' ||
                        c.tipo|| ';' ||
                        c.tot_prevision|| ';' ||
                        c.mto_original|| ';' ||
                        c.tip_destino|| ';' ||
                        c.cod_sec_credito|| ';' ||
                        c.cat_renovaciones|| ';' ||
                        c.cat_ren_anterior|| ';' ||
                        c.lib_prevision|| ';' ||
                        c.tot_pri_prevision|| ';' ||
                        c.cod_rub_economico|| ';' ||
                        c.tot_cap_pri_prevision|| ';' ||
                        c.tot_cap_seg_prevision|| ';' ||
                        c.tot_int_pri_prevision|| ';' ||
                        c.tot_int_seg_prevision|| ';' ||
                        c.mto_pre_total|| ';' ||
                        c.cat_pre_diferida|| ';' ||
                        c.cat_prevision|| ';' ||
                        c.tot_seg_prevision|| ';' ||
                        c.tot_gar_aplicada|| ';' ||
                        c.tot_rie_no_cubierto|| ';' ||
                        c.cli_cat_sistema|| ';' ||
                        c.cli_cat_automatica|| ';' ||
                        c.cli_cat_subjetiva|| ';' ||
                        c.cli_cat_riesgo;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_CTA_CLA_OPERACIONES',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;


PROCEDURE LP_GEN_PER_REF_PERSONALES(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select b.cod_tip_documento,
           b.nro_documento,
           a.cod_referencia,
           a.tip_referencia,
           a.nro_secuencia,
           a.nom_persona,
           a.telefonos,
           a.lug_trabajo,
           a.puesto,
           a.rel_persona,
           fug_eli_car_especiales(a.observacion) observacion,
           a.est_verificacion,
           a.conoce,
           a.rec_mensaje,
           a.cnf_dat_particulares,
           a.cnf_dat_laborales,
           a.cod_usu_verificador,
           a.obs_verificacion,
           to_char(a.fec_verificacion,'dd/mm/yyyy') fec_verificacion,
           a.cod_inf_laboral,
           a.nom_per_informo,
           a.car_per_informo,
           a.nom_per_certifico,
           a.car_per_certifico
      from cr_ref_personales a, ba_personas b
     where b.cod_persona = a.cod_persona
       and trunc(a.fec_modificacion) = v_fecha
       and (exists (select 1 from pr_cta_prestamos c, ge_cta_clientes d
                    where d.nro_cuenta = c.nro_cuenta
                      and c.estado != 'N'
--                      and c.cod_modalidad <> 627
                      and d.cod_persona = a.cod_persona)
       or exists (select 1 from ta_cta_tarjetas e, ge_cta_clientes f
                   where e.nro_cuenta = f.nro_cuenta
                     and f.cod_persona = a.cod_persona
                     and e.estado != 'C'))
  order by 1,2,3,4,5;

     BEGIN
       v_nom_archivo := 'CR_IMP_PER_REF_PERSONALES_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'COD_TIP_DOCUMENTO'|| ';' ||
                     'NRO_DOCUMENTO'|| ';' ||
                     'COD_REFERENCIA'|| ';' ||
                     'TIP_REFERENCIA'|| ';' ||
                     'NRO_SECUENCIA'|| ';' ||
                     'NOM_PERSONA'|| ';' ||
                     'TELEFONOS'|| ';' ||
                     'LUG_TRABAJO'|| ';' ||
                     'PUESTO'|| ';' ||
                     'REL_PERSONA'|| ';' ||
                     'OBSERVACION'|| ';' ||
                     'EST_VERIFICACION'|| ';' ||
                     'CONOCE'|| ';' ||
                     'REC_MENSAJE'|| ';' ||
                     'CNF_DAT_PARTICULARES'|| ';' ||
                     'CNF_DAT_LABORALES'|| ';' ||
                     'COD_USU_VERIFICADOR'|| ';' ||
                     'OBS_VERIFICACION'|| ';' ||
                     'FEC_VERIFICACION'|| ';' ||
                     'COD_INF_LABORAL'|| ';' ||
                     'NOM_PER_INFORMO'|| ';' ||
                     'CAR_PER_INFORMO'|| ';' ||
                     'NOM_PER_CERTIFICO'|| ';' ||
                     'CAR_PER_CERTIFICO';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.cod_tip_documento|| ';' ||
                        c.nro_documento|| ';' ||
                        c.cod_referencia|| ';' ||
                        c.tip_referencia|| ';' ||
                        c.nro_secuencia|| ';' ||
                        c.nom_persona|| ';' ||
                        c.telefonos|| ';' ||
                        c.lug_trabajo|| ';' ||
                        c.puesto|| ';' ||
                        c.rel_persona|| ';' ||
                        c.observacion|| ';' ||
                        c.est_verificacion|| ';' ||
                        c.conoce|| ';' ||
                        c.rec_mensaje|| ';' ||
                        c.cnf_dat_particulares|| ';' ||
                        c.cnf_dat_laborales|| ';' ||
                        c.cod_usu_verificador|| ';' ||
                        c.obs_verificacion|| ';' ||
                        c.fec_verificacion|| ';' ||
                        c.cod_inf_laboral|| ';' ||
                        c.nom_per_informo|| ';' ||
                        c.car_per_informo|| ';' ||
                        c.nom_per_certifico|| ';' ||
                        c.car_per_certifico;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_PER_REF_PERSONALES',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_PER_INF_LABORALES(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select b.cod_tip_documento,
           b.nro_documento,
           a.nro_secuencia,
           fug_eli_car_especiales(a.lug_trabajo) lug_trabajo,
           to_char(a.fec_ingreso,'dd/mm/yyyy') fec_ingreso,
           to_char(a.fec_salida,'dd/mm/yyyy') fec_salida,
           nvl(a.mto_ingreso,0) mto_ingreso,
           a.cod_moneda,
           a.des_puesto,
           a.tip_cargo,
           a.tip_ingreso,
           a.actual,
           a.tip_empleo,
           a.cod_ramo,
           fug_eli_car_especiales(a.observacion) observacion,
           a.cod_direccion,
           a.cod_telefono,
           a.dir_correo,
           a.nom_per_contacto
      from cr_inf_laborales a, ba_personas b
     where b.cod_persona = a.cod_persona
       and trunc(a.fec_modificacion) = v_fecha
       and (exists (select 1 from pr_cta_prestamos c, ge_cta_clientes d
                    where d.nro_cuenta = c.nro_cuenta
                      and c.estado != 'N'
--                      and c.cod_modalidad <> 627
                      and d.cod_persona = a.cod_persona)
       or exists (select 1 from ta_cta_tarjetas e, ge_cta_clientes f
                   where e.nro_cuenta = f.nro_cuenta
                     and f.cod_persona = a.cod_persona
                     and e.estado != 'C'))
    order by 1,2,3;

     BEGIN
       v_nom_archivo := 'CR_IMP_PER_INF_LABORALES_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'COD_TIP_DOCUMENTO'|| ';' ||
                     'NRO_DOCUMENTO'|| ';' ||
                     'NRO_SECUENCIA'|| ';' ||
                     'LUG_TRABAJO'|| ';' ||
                     'FEC_INGRESO'|| ';' ||
                     'FEC_SALIDA'|| ';' ||
                     'MTO_INGRESO'|| ';' ||
                     'COD_MONEDA'|| ';' ||
                     'DES_PUESTO'|| ';' ||
                     'TIP_CARGO'|| ';' ||
                     'TIP_INGRESO'|| ';' ||
                     'ACTUAL'|| ';' ||
                     'TIP_EMPLEO'|| ';' ||
                     'COD_RAMO'|| ';' ||
                     'OBSERVACION'|| ';' ||
                     'COD_DIRECCION'|| ';' ||
                     'COD_TELEFONO'|| ';' ||
                     'DIR_CORREO'|| ';' ||
                     'NOM_PER_CONTACTO';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.cod_tip_documento|| ';' ||
                        c.nro_documento|| ';' ||
                        c.nro_secuencia|| ';' ||
                        c.lug_trabajo|| ';' ||
                        c.fec_ingreso|| ';' ||
                        c.fec_salida|| ';' ||
                        c.mto_ingreso|| ';' ||
                        c.cod_moneda|| ';' ||
                        c.des_puesto|| ';' ||
                        c.tip_cargo|| ';' ||
                        c.tip_ingreso|| ';' ||
                        c.actual|| ';' ||
                        c.tip_empleo|| ';' ||
                        c.cod_ramo|| ';' ||
                        c.observacion|| ';' ||
                        c.cod_direccion|| ';' ||
                        c.cod_telefono|| ';' ||
                        c.dir_correo|| ';' ||
                        c.nom_per_contacto;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_PER_INF_LABORALES',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_PER_TELEFONOS(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  TYPE rec_telefono IS RECORD( cod_tip_documento ba_personas.cod_tip_documento%type,
                               nro_documento     ba_personas.nro_documento%type,
                               tipo              ba_telefonos.tipo%type,
                               tip_linea         ba_telefonos.tip_linea%type,
                               telefono          ba_telefonos.telefono%type,
                               principal         ba_telefonos.principal%type,
                               area              ba_telefonos.area%type,
                               interno           ba_telefonos.interno%type,
                               observacion       ba_telefonos.observacion%type,
                               cod_telefono      ba_telefonos.cod_telefono%type,
                               sms_habilitado    ba_telefonos.sms_habilitado%type);
  
  type tof_rec_telefono is table of rec_telefono;
  v_telefono tof_rec_telefono;
    
  cursor c_telefono is
    select b.cod_tip_documento,
           b.nro_documento,
           a.tipo,
           a.tip_linea,
           fug_eli_car_especiales(a.telefono) telefono,
           a.principal,
           a.area,
           a.interno,
           fug_eli_car_especiales(a.observacion) observacion,
           a.cod_telefono,
           a.sms_habilitado
      from ba_telefonos a, ba_personas b
     where b.cod_persona = a.cod_persona
       --and trunc(a.fec_modificacion) >= (v_fecha-30)
       and (exists (select 1 from pr_cta_prestamos c, ge_cta_clientes d
                where d.nro_cuenta = c.nro_cuenta
                  and c.estado != 'N'
--                  and c.cod_modalidad <> 627
                  and d.cod_persona = a.cod_persona)
         or exists (select 1 from ta_cta_tarjetas e, ge_cta_clientes f
                where e.nro_cuenta = f.nro_cuenta
                  and f.cod_persona = a.cod_persona
                  and e.estado != 'C'))
    order by 1,2,3;

     BEGIN
       v_nom_archivo := 'CR_IMP_PER_TELEFONOS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'COD_TIP_DOCUMENTO'|| ';' ||
                     'NRO_DOCUMENTO'|| ';' ||
                     'TIPO'|| ';' ||
                     'TIP_LINEA'|| ';' ||
                     'TELEFONO'|| ';' ||
                     'PRINCIPAL'|| ';' ||
                     'AREA'|| ';' ||
                     'INTERNO'|| ';' ||
                     'OBSERVACION'|| ';' ||
                     'COD_TELEFONO'|| ';' ||
                     'SMS_HABILITADO';
        utl_file.put_line(v_archivo, v_registro);
        
      BEGIN
        OPEN c_telefono;
        LOOP
          FETCH c_telefono BULK COLLECT INTO v_telefono LIMIT c_limit;
          EXIT WHEN v_telefono.COUNT = 0;

          FOR i IN 1 .. v_telefono.COUNT LOOP
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        v_telefono(i).cod_tip_documento|| ';' ||
                        v_telefono(i).nro_documento|| ';' ||
                        v_telefono(i).tipo|| ';' ||
                        v_telefono(i).tip_linea|| ';' ||
                        v_telefono(i).telefono|| ';' ||
                        v_telefono(i).principal|| ';' ||
                        v_telefono(i).area|| ';' ||
                        v_telefono(i).interno|| ';' ||
                        v_telefono(i).observacion|| ';' ||
                        v_telefono(i).cod_telefono|| ';' ||
                        v_telefono(i).sms_habilitado;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
        end loop;
           CLOSE c_telefono;
       END;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_PER_TELEFONOS',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_PER_MAIL(p_archivo out UTL_FILE.FILE_TYPE,
                          p_directorio in varchar2,
                          p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_mail is
    select b.cod_tip_documento,
           b.nro_documento,
           a.tipo,
           a.dir_correo,
           a.principal,
           fug_eli_car_especiales(a.observacion) observacion
      from ba_mails a, ba_personas b
     where b.cod_persona = a.cod_persona
       and (exists (select 1 from pr_cta_prestamos c, ge_cta_clientes d
                where d.nro_cuenta = c.nro_cuenta
                  and c.estado != 'N'
                  and d.cod_persona = a.cod_persona)
         or exists (select 1 from ta_cta_tarjetas e, ge_cta_clientes f
                where e.nro_cuenta = f.nro_cuenta
                  and f.cod_persona = a.cod_persona
                  and e.estado != 'C'))
    order by 1,2,3;

     BEGIN
       v_nom_archivo := 'CR_IMP_PER_MAIL_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'COD_TIP_DOCUMENTO'|| ';' ||
                     'NRO_DOCUMENTO'|| ';' ||
                     'TIPO'|| ';' ||
                     'DIR_CORREO'|| ';' ||
                     'PRINCIPAL'|| ';' ||
                     'OBSERVACION';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_mail loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.cod_tip_documento|| ';' ||
                        c.nro_documento|| ';' ||
                        c.tipo|| ';' ||
                        c.dir_correo|| ';' ||
                        c.principal|| ';' ||
                        c.observacion;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_PER_MAIL',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab); 
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;     

PROCEDURE LP_GEN_PER_DIRECCIONES(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_garantias is
    select b.cod_tip_documento,
           b.nro_documento,
           a.cod_direccion,
           a.tipo,
           a.principal,
           fug_eli_car_especiales(a.direccion) direccion,
           a.cod_pais,
           a.cod_ciudad,
           a.cod_barrio,
           fug_eli_car_especiales(a.observacion) observacion,
           a.numero,
           a.departamento,
           a.piso,
           a.edificio,
           a.cod_postal,
           a.latitud,
           a.longitud
      from ba_direcciones a, ba_personas b
     where b.cod_persona = a.cod_persona
       and trunc(a.fec_modificacion) >= (v_fecha-30)
       and (exists (select 1 from pr_cta_prestamos c, ge_cta_clientes d
                where d.nro_cuenta = c.nro_cuenta
                  and c.estado != 'N'
--                  and c.cod_modalidad <> 627
                  and d.cod_persona = a.cod_persona)
        or exists (select 1 from ta_cta_tarjetas e, ge_cta_clientes f
                    where e.nro_cuenta = f.nro_cuenta
                      and f.cod_persona = a.cod_persona
                      and e.estado != 'C'))
    order by 1,2,3,4;

     BEGIN
       v_nom_archivo := 'CR_IMP_PER_DIRECCIONES_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'COD_TIP_DOCUMENTO'|| ';' ||
                     'NRO_DOCUMENTO'|| ';' ||
                     'COD_DIRECCION'|| ';' ||
                     'TIPO'|| ';' ||
                     'PRINCIPAL'|| ';' ||
                     'DIRECCION'|| ';' ||
                     'COD_PAIS'|| ';' ||
                     'COD_CIUDAD'|| ';' ||
                     'COD_BARRIO'|| ';' ||
                     'OBSERVACION'|| ';' ||
                     'NUMERO'|| ';' ||
                     'DEPARTAMENTO'|| ';' ||
                     'PISO'|| ';' ||
                     'EDIFICIO'|| ';' ||
                     'COD_POSTAL'|| ';' ||
                     'LATITUD'|| ';' ||
                     'LONGITUD';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_garantias loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.cod_tip_documento|| ';' ||
                        c.nro_documento|| ';' ||
                        c.cod_direccion|| ';' ||
                        c.tipo|| ';' ||
                        c.principal|| ';' ||
                        c.direccion|| ';' ||
                        c.cod_pais|| ';' ||
                        c.cod_ciudad|| ';' ||
                        c.cod_barrio|| ';' ||
                        c.observacion|| ';' ||
                        c.numero|| ';' ||
                        c.departamento|| ';' ||
                        c.piso|| ';' ||
                        c.edificio|| ';' ||
                        c.cod_postal|| ';' ||
                        c.latitud|| ';' ||
                        c.longitud;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_PER_DIRECCIONES',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;

PROCEDURE LP_GEN_CTA_SOBREGIRO(p_archivo out UTL_FILE.FILE_TYPE,
                             p_directorio in varchar2,
                             p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  cursor c_cta_sobregiro is
      select e.nro_documento,
             e.nom_completo,
             d.denominacion,
             d.cod_moneda,
             d.cod_modalidad,
             d.fec_apertura,
             d.estado,
             case
               when e.tipo = 'F' then
                trim(f.pri_nombre) || ' ' || trim(f.seg_nombre)
               else
                trim(e.nom_completo)
             end as nom_cliente,
             trim(f.pri_apellido) || ' ' || trim(f.seg_apellido) as ape_cliente,
             e.tipo,
             e.cod_tip_documento cod_tipo_doc_cliente,
             f.cod_sexo sexo,
             g.cli_confidencial,
             g.cli_especial,
             fug_es_empleado(f.cod_persona) es_funcionario,
             nvl(to_char(f.fec_nacimiento,'DD/MM/YYYY'), to_char(j.fec_apertura,'DD/MM/YYYY')) fec_nacimiento,
             decode(c.relacion, 'Y', 'C', c.relacion) relacion,
             g.cod_oficina cod_ofi_cliente,
             g.cod_oficina cod_ofi_operacion,
             g.cod_usu_oficial ,
             g.cod_seg_cliente,
             a.nro_cuenta,
             a.fecha,
             a.saldo,
             a.liquidado,
             a.usu_insercion,
             a.fec_insercion,
             a.usu_modificacion,
             a.fec_modificacion,
             a.sal_total,
             a.sal_retenido,
             a.mto_linea,
             a.can_dias,
             a.mto_lin_transitoria,
             a.can_dia_sobregiro,
             a.generado
        from cc_sobregiros a, ge_cta_clientes c, ge_cuentas d, ba_personas e, ba_per_fisicas f, ge_clientes g, ba_per_juridicas j
       where a.can_dias >= 0
         and a.fecha = v_fecha
         and c.nro_cuenta = a.nro_cuenta
         and c.relacion = 'P'
         and d.nro_cuenta = c.nro_cuenta
         and e.cod_persona = c.cod_persona
         and e.cod_persona = f.cod_persona(+)
         and g.cod_persona = e.cod_persona
         and c.cod_persona = g.cod_persona
         and e.cod_persona = j.cod_persona(+);

     BEGIN
       v_nom_archivo := 'CR_IMP_SOB_CUENTAS_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'COD_ENTE' || ';' ||
                     'NRO_OPERACION'||';'||
                     'DENOMINACION'||';'||
                     'COD_MONEDA'|| ';' ||
                     'COD_MODALIDAD'|| ';' ||
                     'FEC_APERTURA'|| ';' ||
                     'ESTADO'|| ';' ||
                     'NOM_CLIENTE'|| ';' ||
                     'APE_CLIENTE'|| ';' ||
                     'TIPO'|| ';' ||
                     'NRO_DOC_CLIENTE' || ';' ||
                     'COD_TIPO_DOC_CLIENTE'|| ';' ||
                     'SEXO'|| ';' ||
                     'CLI_CONFIDENCIAL'|| ';' ||
                     'CLI_ESPECIAL'|| ';' ||
                     'ES_FUNCIONARIO'|| ';' ||
                     'FEC_NACIMIENTO'|| ';' ||
                     'RELACION'|| ';' ||
                     'COD_OFI_CLIENTE'|| ';' ||
                     'COD_OFI_OPERACION'|| ';' ||
                     'COD_SEG_CLIENTE'|| ';' ||
                     'COD_USU_OFICIAL'|| ';' ||
                     'FECHA'|| ';' ||
                     'SALDO'|| ';' ||
                     'LIQUIDADO'|| ';' ||
                     'USU_INSERCION'|| ';' ||
                     'FEC_INSERCION'|| ';' ||
                     'USU_MODIFICACION'|| ';' ||
                     'FEC_MODIFICACION'|| ';' ||
                     'SAL_TOTAL'|| ';' ||
                     'SAL_RETENIDO'|| ';' ||
                     'MTO_LINEA'|| ';' ||
                     'CAN_DIAS'|| ';' ||
                     'MTO_LIN_TRANSITORIA'|| ';' ||
                     'CAN_DIA_SOBREGIRO'|| ';' ||
                     'GENERADO';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_cta_sobregiro loop
          v_cont_cab  := v_cont_cab + 1;
          v_registro := p_cod_entidad|| ';' ||
                        c.nro_cuenta|| ';' ||
                        c.denominacion|| ';' ||
                        c.cod_moneda|| ';' ||
                        c.cod_modalidad|| ';' ||
                        c.fec_apertura|| ';' ||
                        c.estado|| ';' ||
                        c.nom_cliente|| ';' ||
                        c.ape_cliente|| ';' ||
                        c.tipo|| ';' ||
                        c.nro_documento|| ';' ||
                        c.cod_tipo_doc_cliente|| ';' ||
                        c.sexo|| ';' ||
                        c.cli_confidencial|| ';' ||
                        c.cli_especial|| ';' ||
                        c.es_funcionario|| ';' ||
                        c.fec_nacimiento|| ';' ||
                        c.relacion|| ';' ||
                        c.cod_ofi_cliente|| ';' ||
                        c.cod_ofi_operacion|| ';' ||
                        c.cod_seg_cliente|| ';' ||
                        c.cod_usu_oficial|| ';' ||
                        c.fecha|| ';' ||
                        c.saldo|| ';' ||
                        c.liquidado|| ';' ||
                        c.usu_insercion|| ';' ||
                        c.fec_insercion|| ';' ||
                        c.usu_modificacion|| ';' ||
                        c.fec_modificacion|| ';' ||
                        c.sal_total|| ';' ||
                        c.sal_retenido|| ';' ||
                        c.mto_linea|| ';' ||
                        c.can_dias|| ';' ||
                        c.mto_lin_transitoria|| ';' ||
                        c.can_dia_sobregiro|| ';' ||
                        c.generado;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');                
         lp_ins_log('LP_GEN_CTA_SOBREGIRO',v_hor_ini,v_hor_fin,v_nom_archivo,v_cont_cab);
         
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;
     
PROCEDURE LP_GEN_LOG(p_archivo out UTL_FILE.FILE_TYPE,
                     p_directorio in varchar2,
                     p_cod_entidad in varchar2)
IS
  v_registro     varchar2(8000);
  v_archivo      UTL_FILE.FILE_TYPE;
  v_hor_ini      ge_log_procesos.hor_inicio%type;
  v_hor_fin      ge_log_procesos.hor_fin%type;
  
  cursor c_log is
    select p.fecha,
           p.cod_programa,
           p.cod_proceso,
           p.hor_inicio,
           p.hor_fin,
           p.observacion
    from ge_log_procesos p
    where p.cod_programa = 'PRG_GEN_ARC_COBROS'
    and   p.fecha        = v_fecha
    and   p.hor_inicio  >= v_hor_ini
    and   p.hor_fin     <= v_hor_fin
    order by fec_insercion;

     BEGIN       
       BEGIN
         SELECT hor_inicio, hor_fin
            INTO v_hor_ini, v_hor_fin
          FROM (
              SELECT p.hor_inicio, p.hor_fin
              FROM ge_log_procesos p
              WHERE p.cod_programa = 'PRG_GEN_ARC_COBROS'
                AND p.cod_proceso  = 'PRG_GEN_ARC_COBROS'
                AND p.fecha        =  v_fecha              
              ORDER BY p.fec_insercion DESC
          )      
          WHERE ROWNUM = 1; 
       EXCEPTION
        WHEN OTHERS THEN
          v_hor_ini := v_hor_inicial;
          v_hor_fin := to_char(sysdate, 'hh24:mi:ss');
       END; 
             
       v_nom_archivo := 'CR_IMP_LOG_'||p_cod_entidad||'.CSV';
       v_archivo   := utl_file.fopen(p_directorio, v_nom_archivo, 'w', 32767);
       v_registro := 'FECHA' || ';' ||
                     'COD_PROGRAMA'|| ';' ||
                     'COD_PROCESO'|| ';' ||
                     'HOR_INICIO'|| ';' ||
                     'HOR_FIN'|| ';' ||
                     'NOMBRE_ARCHIVO;CANT_REGISTROS';
        utl_file.put_line(v_archivo, v_registro);
        for c in c_log loop
          v_registro := c.fecha|| ';' ||
                        c.cod_programa|| ';' ||
                        c.cod_proceso|| ';' ||
                        c.hor_inicio|| ';' ||
                        c.hor_fin|| ';' ||
                        c.observacion;
           utl_file.put_line(v_archivo, v_registro);
         end loop;
         utl_file.fclose(v_archivo);
         p_archivo := v_archivo;
     END;
 
 FUNCTION LF_VER_PROCESADO(p_cod_proceso varchar2, p_fecha date) 
    return number is
    v_proceso number default 0;    
  begin
       select count(*)
          into v_proceso
          from ge_log_procesos p
         where p.cod_programa = p_cod_proceso
           and p.cod_proceso  = p_cod_proceso
           and p.fecha = p_fecha;
    return v_proceso;  
  exception
  when others then       
      return 0;
end;
BEGIN
  lp_act_mat_view(p_tip_proceso);
  if p_fecha is null then
    v_fecha := pag_cal.fu_obt_fec_anterior(1);
  else
    v_fecha := p_fecha;
  end if;
  v_directorio := fug_obt_pardinamico('GEN_DIR_ARC_COB');
  v_hor_inicial := to_char(sysdate,'hh24:mi:ss');
  if nvl(p_tip_proceso,'N') = 'N' then
    v_procesado:= lf_ver_procesado('PRG_GEN_ARC_COBROS', v_fecha);
    if v_procesado = 0 or v_procesado = 1 then       
      for e in entidad loop  
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');
         v_cont_cab := 0;
         v_cont_det := 0;
         LP_GEN_PRE_CUENTAS(v_archivo,
                         v_directorio,
                         e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');                
         v_cont_cab := 0;
         v_cont_det := 0;       
         LP_GEN_PRE_PAGOS(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');                       
         v_cont_cab := 0;
         v_cont_det := 0;       
         LP_GEN_TAR_CUENTAS(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');                       
         v_cont_cab := 0;
         v_cont_det := 0;       
         LP_GEN_TAR_PAGO(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');                       
         v_cont_cab := 0;
         v_cont_det := 0;       
         LP_GEN_PRE_PREVISIONES(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;              
         LP_GEN_GARANTIAS(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_CTA_GARANTIAS(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_GAR_HIPOTECAS(v_archivo,
                        v_directorio,
                        e.cod_entidad);
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_GAR_AVALES(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_GAR_CASH(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_GAR_DOCUMENTOS(v_archivo,
                        v_directorio,
                        e.cod_entidad);
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');                        
         LP_GEN_GAR_FIDEICOMISO(v_archivo,
                        v_directorio,
                        e.cod_entidad);
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_GAR_STANDBYS(v_archivo,
                        v_directorio,
                        e.cod_entidad);
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_GAR_VEHICULOS(v_archivo,
                        v_directorio,
                        e.cod_entidad);
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_GAR_WARRANTS(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_CTA_CLA_OPERACIONES(v_archivo,
                        v_directorio,
                        e.cod_entidad);        
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_PER_REF_PERSONALES(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_PER_INF_LABORALES(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_PER_TELEFONOS(v_archivo,
                        v_directorio,
                        e.cod_entidad);
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_PER_MAIL(v_archivo,
                        v_directorio,
                        e.cod_entidad);          
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_PER_DIRECCIONES(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_OVE_VENCIDA(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_OVE_PAGOS(v_archivo,
                        v_directorio,
                        e.cod_entidad);         
         v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
         v_cont_cab := 0;
         v_cont_det := 0;                             
         LP_GEN_CTA_SOBREGIRO(v_archivo,
                        v_directorio,
                        e.cod_entidad);
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         lp_ins_log('PRG_GEN_ARC_COBROS',v_hor_inicial,v_hor_fin,null,null);       
         --Archivo log de procesos
         LP_GEN_LOG(v_archivo,v_directorio,e.cod_entidad);                     
      end loop;   
    end if;
  
  elsif nvl(p_tip_proceso,'N') = 'S' then
    for e in entidad loop
       v_hor_ini := to_char(sysdate,'hh24:mi:ss');
       v_cont_cab := 0;
       v_cont_det := 0;        
       LP_GEN_PRE_PAGOS(v_archivo,
                      v_directorio,
                      e.cod_entidad);              
    end loop;
  elsif nvl(p_tip_proceso,'N') = 'T' then
    for e in entidad loop
       v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
       v_cont_cab := 0;
       v_cont_det := 0;       
       LP_GEN_TAR_CUENTAS(v_archivo,
                      v_directorio,
                      e.cod_entidad);
       
       v_hor_ini := to_char(sysdate,'hh24:mi:ss'); 
       v_cont_cab := 0;
       v_cont_det := 0;                             
       LP_GEN_TAR_PAGO(v_archivo,
                      v_directorio,
                      e.cod_entidad);                    
    end loop;
  end if;  
 
EXCEPTION
  WHEN no_data_found THEN    
      --- Fin del archivo
      utl_file.fclose(v_archivo);
   WHEN utl_file.invalid_path THEN 
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Directorio invalido');
   WHEN utl_file.invalid_mode THEN     
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Modo invalido');
   WHEN utl_file.invalid_filehandle THEN      
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Invalida Filehandle');
   WHEN utl_file.invalid_operation THEN  
      --- Fin del archivo
      utl_file.fclose(v_archivo);
   WHEN utl_file.read_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Lectura errada');
   WHEN utl_file.write_error THEN     
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Escritura errada'||sqlerrm);
   WHEN utl_file.internal_error THEN    
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Error interno');
  WHEN others THEN
     --- Fin del archivo
     utl_file.fclose(v_archivo); 
     raise_application_error(-20000, 'Error: '||v_nom_archivo||'-'||sqlerrm);     
END;

