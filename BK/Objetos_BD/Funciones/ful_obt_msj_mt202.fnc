CREATE OR REPLACE FUNCTION IT."FUL_OBT_MSJ_MT202" (p_nro_operacion in number)
  RETURN VARCHAR2 IS
  v_nom_archivo varchar2(100) := null;
  v_texto varchar2(3000) := null;
  cursor c_transf is
     select NRO_REFERENCIA,COD_TIP_REFERENCIA,COD_MODULO,COD_MODALIDAD,COD_OFICINA,
            fec_operacion,nro_operacion, cod_moneda, monto, saldo, cod_banco,
            translate(nom_banco,'añ#$/´"%','a') nom_banco,
            cod_pai_banco, cod_ciu_banco,
            translate(cod_aba_banco,'añ#$/´"%','a') cod_aba_banco,
            translate(cod_swi_banco,'añ#$/´"%','a') cod_swi_banco,
            cod_bco_corresponsal, cod_per_solicitante,
            translate(nom_solicitante,'añ#$/´"%','a') nom_solicitante,
            translate(dir_solicitante,'añ#$/´"%','a') dir_solicitante, tel_solicitante,
            cod_pai_solicitante, cod_ciu_solicitante, cod_per_beneficiario,
            translate(nom_beneficiario,'añ#$/´"%','a') nom_beneficiario,
            translate(dir_beneficiario,'añ#$/´"%','a') dir_beneficiario, tel_beneficiario,
            cod_pai_beneficiario, cod_ciu_beneficiario,
            nro_cta_referencia, fec_ult_movimiento, fec_recepcion,cod_rubro,plazo,
            translate(observacion,'añ#$/´"%','a') observacion,
            usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,cod_uid_banco,
            nro_ref_externa, tip_mensaje, tip_cargo, cod_bco_cor_contra,
            translate(nom_ciu_beneficiario,'añ#$/´"%','a') nom_ciu_beneficiario,
            translate(nom_ciu_solicitante,'añ#$/´"%','a') nom_ciu_solicitante,
            estado, msj_swift, fec_cam_estado,nro_doc_beneficiario, est_anterior, enviada,
            fec_valor, cod_msj_swift,
            fec_envio, hor_envio,
            mto_cargo, nro_sec_lote, tip_fondo, tip_motivo, tip_financiacion,
            translate(nom_ordenante,'añ#$/´"%','a') nom_ordenante,
            tip_ref_obs,age_banco,
            translate(nom_bco_cor_contra, 'añ#$/´"%','a') nom_bco_cor_contra,
            cod_swi_bco_contra,cod_aba_bco_contra, cta_cobranza, fondeado
       from lc_transferencias
      where nro_operacion = p_nro_operacion;
  ct c_transf%rowtype;
  v_cod_swift            varchar2(20);
  v_salto                varchar2(2) := CHR(13)||CHR(10);
  v_nro_cta_corresponsal varchar2(50);
  v_cod_swi_corresponsal varchar2(12);
  v_nom_bco_cor_contra   varchar2(100);
  v_cod_swi_cor_contra   varchar2(50);
  v_cod_per_cor_contra   varchar2(20);
  v_cod_pai_cor_contra   number(5);
  v_des_pai_cor_contra   varchar2(100);
  v_cod_ciu_cor_contra   number(5);
  v_des_ciu_cor_contra   varchar2(100);
  v_det_cargo            varchar2(1):='N';

/*  FB:21.09.2009 Se agrega esta sentencia a cada linea para eliminar los caracteres especiales además la ñ y controlar
  que cada linea no supere los 35 caracteres: FU_SIM_NORM_CADENA(replace(v_texto,'ñ',''),35)*/
BEGIN
  pre_cam_for_numerico('.,');
  -- defino el nombre del archivo
  v_nom_archivo := 'TR_EMITIDAS'||p_nro_operacion||'.DAT';
  -- leo los datos del registro de la operacion
  open c_transf;
  fetch c_transf into ct;
  close c_transf;
  -- obtengo los datos del banco corresponsal
  begin
      select upper(b.cod_swift), a.nro_cuenta
        into v_cod_swi_corresponsal, v_nro_cta_corresponsal
        from ge_bancos b, cc_cta_bancarias a
       where a.cod_moneda = ct.cod_moneda
         and a.estado = 'N'
         and a.cod_modalidad = 45
         and a.cod_banco = ct.cod_bco_corresponsal
         and b.cod_banco = a.cod_banco;
  exception
      when no_data_found then
        raise_application_error(-20009,'Corresponsal inexistente');
      when too_many_rows then
        raise_application_error(-20010,'Varios Correponsales definidos');
      when others then
        raise_application_error(-20011,'Recup.Corresp.'|| sqlerrm);
  end;
  -- obtengo los datos del banco corresponsal del operante
  begin
     select a.descripcion, upper(a.cod_swift), a.cod_persona
       into v_nom_bco_cor_contra, v_cod_swi_cor_contra, v_cod_per_cor_contra
       from ge_bancos a
      where a.cod_banco = ct.cod_bco_cor_contra;
  exception
     when others then
         v_nom_bco_cor_contra := null;
         v_cod_swi_cor_contra := null;
  end;
  pre_obt_ciu_pais(v_cod_per_cor_contra, v_cod_pai_cor_contra, v_des_pai_cor_contra, v_cod_ciu_cor_contra, v_des_ciu_cor_contra);
  -- obtengo el codigo de swift del banco origen
  select cod_swift into v_cod_swift from ge_bancos where cod_banco = fug_obt_cod_banco;
  -- armo las partes del cuerpo del mensaje
  -- ********************************** cabecera ****************************************************
  -- FB: 21.09.2009 Se comenta la cabecera a pedido de BBVA
/*  v_texto :=          '{1:F21'||v_cod_swift||'AXXX0000000000}';
  v_texto := v_texto||'{2:I'||ct.cod_msj_swift||rpad(upper(v_cod_swi_corresponsal),12,'X')||'N'||'}';
  v_texto := v_texto||'{4:'||v_salto;
*/  -- ****************************** cuerpo del mensaje **********************************************
  -- 20: Numero de referencia
  v_texto := v_texto||substr(':20:'||trim(ct.nro_ref_externa),1,35)||v_salto;
  v_texto := v_texto||substr(':21:'||ct.tip_mensaje,1,35)||v_salto;
  v_texto := v_texto||substr(':32A:'||to_char(ct.fec_valor,'yymmdd')||ct.cod_moneda||trim(replace(to_char(ct.monto,'999999999999.99'),'.',',')),1,35)||v_salto;
  v_texto := v_texto||':57A:'||upper(v_cod_swi_corresponsal)||v_salto;

  if ct.cod_swi_banco is null then
    if ct.nro_cta_referencia is not null then
      v_texto := v_texto||':58A:'||'/'||ct.nro_cta_referencia||v_salto||fug_obt_des_banco(v_cod_per_cor_contra)||v_salto;
    else
      v_texto := v_texto||':58A:'||fug_obt_des_banco(v_cod_per_cor_contra)||v_salto;
    end if;
  else
    if ct.nro_cta_referencia is not null then
      v_texto := v_texto||':58A:'||'/'||ct.nro_cta_referencia||v_salto||upper(ct.cod_swi_banco)||v_salto;
    else
      v_texto := v_texto||':58A:'||upper(ct.cod_swi_banco)||v_salto;
    end if;
  end if;

  --||ct.nom_banco||v_salto||fue_obt_des_ciudad(ct.cod_pai_banco,ct.cod_ciu_banco)||' '||fue_obt_des_pais(ct.cod_pai_banco)||v_salto;
  /*
  if ct.tip_cargo <> 'OUR' then
     v_det_cargo := 'S';
     v_texto := v_texto||substr(':33B:'||ct.cod_moneda||trim(replace(to_char(ct.monto - nvl(ct.mto_cargo,0),'999999999999.99'),'.',',')),1,35)||v_salto;
  end if;
  */
  -- v_texto := v_texto||substr(':50K:/'||ct.cod_per_solicitante,1,35)||v_salto||substr(ct.nom_solicitante,1,35)||v_salto||substr(ct.dir_solicitante,1,35)||v_salto||substr(nvl(ct.nom_ciu_solicitante,fue_obt_des_ciudad(ct.cod_pai_solicitante,ct.cod_ciu_solicitante))||' '||fue_obt_des_pais(ct.cod_pai_solicitante),1,35)||v_salto;
  /*
  if ct.cod_msj_swift = 103 then
     if ct.cod_bco_cor_contra <> 999 then
       -- 56A: Banco intermediario - Corresponsal del banco receptor
       v_texto := v_texto||substr(':56A:'||upper(v_cod_swi_cor_contra),1,35)||v_salto||v_nom_bco_cor_contra||v_salto||v_des_ciu_cor_contra||' '||v_des_pai_cor_contra||v_salto;
       --Cuando se registra el CORRESPONSAL del Banco Operante - Generar    :56D: NOMBRE DEL BANCO SELECCIONADO.
       v_texto := v_texto||'56D:'||upper(v_nom_bco_cor_contra)||v_salto;
     end if;
     -- 57A: Banco del beneficiario
     if ct.cod_banco = 999 then
        if ct.cod_swi_banco is not null then
        --Cuando se tipea 999 en el Codigo del Banco y se registra algo en el campo SWIFT - Generar    :57A: ABCH009 (CAMPO SWIFT)
           v_texto := v_texto||':57A:'||upper(ct.cod_swi_banco)||v_salto; --||v_salto||ct.nom_banco||v_salto||fue_obt_des_ciudad(ct.cod_pai_banco,ct.cod_ciu_banco)||' '||fue_obt_des_pais(ct.cod_pai_banco)||v_salto;
        elsif ct.cod_swi_banco is null and ct.cod_aba_banco is not null then
        --Cuando se tipea 999 en el Codigo del Banco y se registra algo en el campo ABA - Generar    :57D: 0987765 (CAMPO ABA)
           v_texto := v_texto||':57D:'||upper(ct.cod_aba_banco)||v_salto;
        else
        --Cuando se tipea 999 en el Codigo del Banco NO se registra nada en el campo SWIFT ni el campo ABA - Generar    :57D: NOMBRE DEL BANCO TIPEADO.
          v_texto := v_texto||substr(':57D:'||upper(ct.nom_banco),1,35)||v_salto;
        end if;
      end if;
     -- 59 : Datos del beneficiario
     v_texto := v_texto||':59:' ||'/'||ct.nro_cta_referencia||v_salto||substr(ct.nom_beneficiario,1,35)||v_salto||substr(ct.dir_beneficiario,1,35)||v_salto||substr(nvl(ct.nom_ciu_beneficiario,fue_obt_des_ciudad(ct.cod_pai_beneficiario, ct.cod_ciu_beneficiario))||' '||fue_obt_des_pais(ct.cod_pai_beneficiario),1,35)||v_salto;
  elsif ct.cod_msj_swift = 202 then
     -- 58 : Datos del banco beneficiario
     v_texto := v_texto||':58A:'||'/'||ct.nro_cta_referencia||v_salto||upper(ct.cod_swi_banco)||v_salto||ct.nom_banco||v_salto||fue_obt_des_ciudad(ct.cod_pai_banco,ct.cod_ciu_banco)||' '||fue_obt_des_pais(ct.cod_pai_banco)||v_salto;
  end if;
  */
  -- 70: COMENTARIO
  if ct.observacion is not null then
     v_texto := v_texto||substr(':70:'||upper(ct.observacion),1,35)||v_salto;
  end if;
  -- 71A: detalles del cargo
--                                                                                                                                     o;
  -- 71F: moneda y monto del cargo
  if v_det_cargo = 'S' then
     --v_texto := v_texto||':71F:'||ct.cod_moneda||trim(replace(to_char(nvl(ct.mto_cargo,0),'999999999999.99'),'.',','))||v_salto;
     v_texto := v_texto||':71F:'||ct.cod_moneda||trim(replace(nvl(ct.mto_cargo,0),'.',','))||','||v_salto;
  end if;
  -- ********************************* fin del texto ************************************************
  v_texto := v_texto||'-}';
  -- fin de la funcion
  RETURN v_nom_archivo||'~'||v_texto;
END;
/

