CREATE OR REPLACE PACKAGE BODY IT.PAM_DOC Is

  cg_fli_ok             CONSTANT NUMBER := 0;
  cg_fli_err_param      CONSTANT NUMBER := 1;
  cg_fli_err_estado     CONSTANT NUMBER := 2;
  cg_fli_err_cobertura  CONSTANT NUMBER := 4;
  cg_fli_err_integridad CONSTANT NUMBER := 5;
  cg_fli_err_conta      CONSTANT NUMBER := 6;
  cg_fli_msg_r5         CONSTANT VARCHAR2(4000) :=
    'Sin cobertura para reasignar garantia FLI. Notificar a IT.';

  CURSOR cur_destinos_fli(p_nro_documento   md_cta_documentos.nro_documento%TYPE,
                          p_nro_cuenta_orig md_cta_documentos.nro_cuenta%TYPE) IS
    SELECT d.nro_cuenta,
           d.monto,
           NVL(d.sal_restringido, 0) sal_restringido,
           d.fec_vencimiento,
           d.estado
      FROM md_cta_documentos d
     WHERE d.nro_documento = p_nro_documento
       AND d.nro_cuenta <> p_nro_cuenta_orig
       AND d.cod_modulo = 10
       AND d.estado IN ('C', 'T', 'R')  /* T037 R9: REPO (R) elegible si DISP >= traslado */
     ORDER BY d.fec_vencimiento ASC NULLS LAST,
              (d.monto - NVL(d.sal_restringido, 0) -
               NVL((SELECT SUM(f.monto)
                      FROM sb_snp_fli f
                     WHERE f.nro_cuenta = d.nro_cuenta
                       AND f.nro_documento = p_nro_documento
                       AND f.situacion = 'V'), 0)) DESC;

  /* Vigente FLI = solo situacion 'V' (N=reasignado origen; L=liquidada) */
  CURSOR cur_fli_origen_doc(p_nro_cuenta    sb_snp_fli.nro_cuenta%TYPE,
                            p_nro_documento sb_snp_fli.nro_documento%TYPE) IS
    SELECT f.nro_referencia,
           f.monto,
           f.nro_cuenta,
           f.nro_ref_externa,
           f.cod_msj_swift,
           f.fecha
      FROM sb_snp_fli f
     WHERE f.nro_cuenta = p_nro_cuenta
       AND f.nro_documento = p_nro_documento
       AND f.situacion = 'V'
     FOR UPDATE;

  FUNCTION fu_requiere_reasigna_fli(p_nro_cuenta      IN md_cta_documentos.nro_cuenta%TYPE,
                                    p_nro_documento   IN md_cta_documentos.nro_documento%TYPE,
                                    p_monto_deseado   IN md_cta_documentos.monto%TYPE,
                                    p_sal_restringido IN md_cta_documentos.sal_restringido%TYPE DEFAULT NULL)
    RETURN BOOLEAN;

  --- TRUE = cobra el ultimo cupon pendiente (venta total) → controles FLI/rest.
  FUNCTION fu_es_venta_documento(p_nro_cuenta IN md_cta_documentos.nro_cuenta%TYPE,
                                 p_nro_cupon  IN NUMBER DEFAULT NULL)
    RETURN BOOLEAN IS
    v_max_cuota md_doc_detalles.nro_cuota%TYPE;
  BEGIN
    --- Ultimo cupon pendiente = MAX nro_cuota con saldo y estado no cancelado.
    SELECT MAX(dd.nro_cuota)
      INTO v_max_cuota
      FROM md_doc_detalles dd
     WHERE dd.nro_cuenta = p_nro_cuenta
       AND dd.nro_cuota > 0
       AND NVL(dd.estado, 'C') <> 'N'
       AND (NVL(dd.sal_capital, 0) <> 0 OR NVL(dd.sal_interes, 0) <> 0);

    IF v_max_cuota IS NULL THEN
      RETURN FALSE;
    END IF;

    --- Sin cupon explicito (cancelacion/venta masiva): incluye el ultimo → venta total.
    IF p_nro_cupon IS NULL THEN
      RETURN TRUE;
    END IF;

    RETURN p_nro_cupon = v_max_cuota;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
  END fu_es_venta_documento;

  --Obtener datos de la operacion
  PROCEDURE PR_OBT_DATOS(P_NRO_CUENTA IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
                  RP_PDOCU     IN OUT MD_CTA_DOCUMENTOS%Rowtype) IS
  BEGIN
    select *
      into rp_pdocu
      from md_cta_documentos
     where nro_cuenta = p_nro_cuenta;
  exception
    when no_data_found then
      raise_application_error(-20000,
                      'Cuenta ' || p_nro_cuenta || ' no registrada.');
  END;
  --Compra de los Documentos
  PROCEDURE PR_COM_DOCUMENTOS(P_NRO_CUENTA     IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
                     P_MTO_DESEMBOLSO IN MD_CTA_DOCUMENTOS.MONTO%Type,
                     P_COD_OFI_ORIGEN IN BA_OFICINAS.COD_OFICINA%TYPE,
                     P_MTO_GARANTIA   IN MD_GARANTIAS.MONTO%TYPE,
                     P_FECHA          IN DATE,
                     P_HORA           IN VARCHAR2,
                     P_NRO_SECUENCIA  IN OUT Varchar2) IS

    --- Variables de tipo de registro
    r_pcta  md_cta_documentos%rowtype;
    r_ctarp md_cta_documentos%rowtype;
    r_gmovi ge_movimientos%rowtype;
    --- Variables para movimientos
    v_nro_secuencia ge_movimientos.nro_secuencia%type;
    v_hora          ge_movimientos.hora%type;
    v_cod_usuario   ge_movimientos.cod_usuario%type;
    --v_mto_interes        md_cta_documentos.mto_interes%type;
    v_error            number(05);
    v_mensaje          varchar2(1000);
    v_cotizacion       ge_cotizaciones.val_conversion%type;
    v_capital          md_cta_documentos.monto%type;
    v_cod_sit_contable md_cta_documentos.cod_sit_contable%type;
    v_cod_mon_local    ba_monedas.cod_moneda%type;
    ---
    v_cod_tra_cargo    number := 704; ----------------- Transaccion por cargo
    v_tot_cargo        number := 0; ------------------- Monto del cargo + impuesto
    v_cod_tas_cargo    number;
    v_val_tas_cargo    number;
    v_val_cargo        number;
    v_cod_tra_impuesto number;
    v_cod_tas_impuesto number;
    v_val_tas_impuesto number;
    v_val_impuesto     number;
    --impuesto
    v_val_tas_iva  number;
    v_fec_vigencia date;
    v_redondeo     number(5);
    v_tip_valor    ge_tasas.tip_valor%type;
    v_tipo         ge_tasas.tipo%type;
    v_cod_tasa     ge_tasas.cod_tasa%type;
    v_concepto     ge_movimientos.concepto%type;
    v_fec_aux      date;
    v_es_nocturno  varchar2(1);

    /*Tratamiento de garantias JCLG*/
    cursor garantias is
      select a.nro_cuenta,
           a.nro_garantia,
           a.cod_garantia,
           nvl(a.cod_moneda, r_pcta.cod_moneda) cod_moneda,
           nvl(p_mto_garantia, 0) monto,
           a.observacion,
           b.cod_transaccion1
        from pr_gar_tipos b, md_garantias a
       where a.nro_cuenta = p_nro_cuenta
        and b.cod_garantia = a.cod_garantia
        and b.cod_transaccion2 is not null
        and rownum = 1; -- ahora se desplica por el monto que dice en pantalla

  BEGIN
    --- Cargar variables
    prg_ver_est_modulo(10,v_es_nocturno,v_fec_aux);
    v_nro_secuencia := p_nro_secuencia;
    v_hora          := p_hora;
    --- Recuperar datos de la Operación
    pr_obt_datos(p_nro_cuenta, r_pcta);
    --
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',10,r_pcta.cod_modalidad,r_pcta.cod_moneda);
    --
    if v_error <> 0 then
       raise_application_error(-20000,
                      v_mensaje || ' ' || 'error:' || v_error);
    end if;
    --- Verificar monto de desembolso
    /*if (p_mto_desembolso <> nvl(r_pcta.monto, 0) - nvl(r_pcta.mto_interes, 0) and
      r_pcta.cod_modalidad not in (110, 114, 116)) or
      (p_mto_desembolso <> nvl(r_pcta.monto, 0) and
      r_pcta.cod_modalidad in (110, 114)) --110 es int vencido
      or (p_mto_desembolso <>
      (nvl(r_pcta.monto, 0) - nvl(r_pcta.mto_impuesto, 0)) and
      r_pcta.cod_modalidad = 116) then
      raise_application_error(-20000,'Monto a comprar no coincide con monto de la operación ');
    end if;*/
    --[INI] [PABASTIDA] [FIELDESK-162108] Agregando modalidades mercado secundario
    --if r_pcta.cod_modalidad in (110,106,114,134,144,142,132,129) OR FUM_OBT_OPE_REPO(r_pcta.cod_modulo,r_pcta.cod_modalidad,'S','O') = 'S' then--110 es int vencido, Repo Otorgado
    if r_pcta.cod_modalidad in (100,101,106,110,114,123,124,129,132,134,144,142) OR FUM_OBT_OPE_REPO(r_pcta.cod_modulo,r_pcta.cod_modalidad,'S','O') = 'S' then--110 es int vencido, Repo Otorgado
    --[FIN] [PABASTIDA] [FIELDESK-162108]
       if p_mto_desembolso <> nvl(r_pcta.monto,0) then
          raise_application_error(-20000,
          'Monto a comprar no coincide con monto de la operación ');
       end if;
    elsif r_pcta.cod_modalidad in (116,146,148) then
       if p_mto_desembolso <> (nvl(r_pcta.monto, 0) - nvl(r_pcta.mto_impuesto, 0)) then
          raise_application_error(-20000,
          'Monto a comprar no coincide con monto de la operación ');
       end if;
    elsif r_pcta.cod_modalidad in (120) then
       if (p_mto_desembolso + nvl(r_pcta.comision, 0)) <> (nvl(r_pcta.monto, 0) - nvl(r_pcta.mto_impuesto, 0)+ nvl(r_pcta.comision, 0)) then
          raise_application_error(-20000,
          'Monto a comprar no coincide con monto de la operación ');
       end if;
    else
       if p_mto_desembolso <> nvl(r_pcta.monto, 0) - nvl(r_pcta.mto_interes, 0) then
          raise_application_error(-20000,
          'Monto a comprar no coincide con monto de la operación ');
       end if;
    end if;

    --- Inicializar variables de movimientos
    v_cod_usuario := user;
    --- busco el valor de la cotizacion
    v_cod_mon_local := pag_gen.fu_obt_mon_local;
    v_cotizacion    := null;
    if r_pcta.cod_moneda <> v_cod_mon_local then
       --- Actualizar cargos a la cotizacion del dia.
       v_cotizacion := fug_obt_cotizacion(r_pcta.cod_moneda, p_fecha);
    end if;

    if r_pcta.cod_modalidad not in (113,110,106,114,116,146,120,122,123,124,134,144,142,132,129) OR FUM_OBT_OPE_REPO(r_pcta.cod_modulo,r_pcta.cod_modalidad,'S','O') = 'S' then -- Repo Otorgado
       --call money otorgado, int vencido
       v_capital := NVL(r_pcta.monto, 0) - NVL(r_pcta.mto_interes, 0);
    else
       v_capital := nvl(r_pcta.monto, 0);
    end if;
    --
    if r_pcta.estado = 'R' then
      -- Busca la situación contable antes de modificar el estado para determinar si es Desembolso de REPO o no.
      r_gmovi.cod_sit_contable := pab_asi.fu_cal_sit_contable(p_nro_cuenta);
      --
      -- Modifica el estado para buscar la situación contable.
      update md_cta_documentos d
         set estado = 'C',
             d.fec_ini_repo = null,
             d.fec_ven_repo = null,
             d.val_bas_repo = null,
             d.val_tas_repo = null
       where nro_cuenta = p_nro_cuenta;
      --
      v_cod_sit_contable := pab_asi.fu_cal_sit_contable(p_nro_cuenta);
      v_concepto := 'Re-Compra Documento ' || p_nro_cuenta;
    elsif r_pcta.estado = 'S' and r_pcta.fec_ven_repo is not null then
      -- Si es una solicitud con fecha vencimiento es un RiverRepo.
      r_gmovi.cod_sit_contable := pab_asi.fu_cal_sit_contable(p_nro_cuenta);
      --
      v_cod_sit_contable := r_gmovi.cod_sit_contable;
      v_concepto := 'Compra Documento ' || p_nro_cuenta;
    else
      -- Si no es una compra de Repo ni RiverRepo busca la situación contable "Normal".
      r_gmovi.cod_sit_contable := pab_asi.fu_cal_sit_contable(p_nro_cuenta);
      --
      v_cod_sit_contable := r_gmovi.cod_sit_contable;
      v_concepto := 'Compra Documento ' || p_nro_cuenta;
    end if;
    --
    --- Generar movimiento de generacion del credito
    v_nro_secuencia         := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_usuario     := v_cod_usuario;
    r_gmovi.hora            := v_hora;
    r_gmovi.fecha           := p_fecha;
    r_gmovi.cod_modulo      := r_pcta.cod_modulo;
    r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
    r_gmovi.cod_oficina     := r_pcta.cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := r_pcta.cod_moneda;
    r_gmovi.est_cuenta      := 'C';
    r_gmovi.cod_tra_padre   := 101;
    r_gmovi.cod_transaccion := 401;
    r_gmovi.fec_valor       := p_fecha;
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.reversado       := 'N';
    r_gmovi.protegido       := 'N';
    r_gmovi.estado          := 'N';
    r_gmovi.concepto        := 'Cambio de Estado';
    r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
    r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
    r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
    r_gmovi.nro_documento   := r_pcta.nro_cuenta;
    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);

    --- actualizo el estado -----------------------
    if r_pcta.estado <> 'R' then
      if (instr(fug_obt_pardinamico('COD_MAD_MER_SECUNDARIO'),','||r_pcta.cod_modalidad||',')=0 ) or
         (instr(fug_obt_pardinamico('COD_MAD_MER_SECUNDARIO'),','||r_pcta.cod_modalidad||',')>0 and r_pcta.mer_secundario = 'N') then
      update md_cta_documentos
        set estado = 'C',
           --sal_val_presente = val_presente,
           sal_capital      = val_presente,
           val_int_devengar = mto_interes,
           cod_sit_contable = v_cod_sit_contable
       where nro_cuenta = p_nro_cuenta;
      else 
       update md_cta_documentos
        set estado = 'C',
           sal_capital      = val_presente,
           cod_sit_contable = v_cod_sit_contable
       where nro_cuenta = p_nro_cuenta;
      end if;
    else
      update md_cta_documentos
         set cod_sit_contable = v_cod_sit_contable
       where nro_cuenta = p_nro_cuenta;
    end if;
    -- Cambio el estado de las cupones
    update md_doc_detalles set estado = 'C' where nro_cuenta = p_nro_cuenta;

    -- genero el movimiento por el capital a contabilizar -----------
    v_nro_secuencia         := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_usuario     := v_cod_usuario;
    r_gmovi.hora            := v_hora;
    r_gmovi.fecha           := p_fecha;
    r_gmovi.cod_modulo      := r_pcta.cod_modulo;
    r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
    r_gmovi.cod_oficina     := r_pcta.cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := r_pcta.cod_moneda;
    r_gmovi.est_cuenta      := null; --no es cambio de estado
    r_gmovi.cod_tra_padre   := 101;
    r_gmovi.cod_transaccion := 711;
    r_gmovi.monto           := v_capital;
    r_gmovi.fec_valor       := p_fecha;
    r_gmovi.emi_aviso       := 'S';
    r_gmovi.reversado       := 'N';
    r_gmovi.protegido       := 'N';
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
    r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
    r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
    r_gmovi.nro_documento   := r_pcta.nro_cuenta;
    r_gmovi.concepto        := v_concepto;
    r_gmovi.cotizacion      := v_cotizacion;
    r_gmovi.mto_equ_local   := round(trunc(v_capital, 2) * v_cotizacion, 0);
    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);

    --- Actualizaciones del devengamiento ----------------------------
    --- genero los movimientos por el devengamiento y el interes ----
    --sólo si no es call money, call money sólo contabiliza capital, tambien Repo Otorgado (128)
    if r_pcta.cod_modalidad not in (110) AND FUM_OBT_OPE_REPO(r_pcta.cod_modulo,r_pcta.cod_modalidad,'S','O') = 'N' then -- Distinto Repo Otorgado
      if r_pcta.cod_modalidad <> 113 then
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := p_fecha;
        r_gmovi.cod_modulo      := r_pcta.cod_modulo;
        r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
        r_gmovi.cod_oficina     := r_pcta.cod_oficina;
        r_gmovi.nro_cuenta      := p_nro_cuenta;
        r_gmovi.cod_moneda      := r_pcta.cod_moneda;
        r_gmovi.est_cuenta      := null;
        r_gmovi.cod_tra_padre   := 101;
        r_gmovi.cod_transaccion := 719;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.monto           := nvl(r_pcta.mto_interes, 0);
        r_gmovi.fec_valor       := p_fecha;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.reversado       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
        r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
        r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
        r_gmovi.nro_documento   := r_pcta.nro_cuenta;
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(trunc(nvl(r_pcta.mto_interes, 0),2) * v_cotizacion,0);
        pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
      end if;
      --impuesto sobre el interés en el desembolso, call money plazo 116
      if r_pcta.mto_impuesto > 0 and r_pcta.cod_modalidad in (116,146) then
        --recupera tasa
        pag_gen.pr_obt_val_tasa(r_pcta.cod_modulo,
                        r_pcta.cod_modalidad,
                        r_pcta.cod_oficina,
                        r_pcta.nro_cuenta,
                        r_pcta.cod_moneda,
                        r_pcta.mto_interes,
                        'N',
                        v_cod_tasa,
                        518, --Transaccion de iva 5%
                        p_fecha,
                        v_val_tas_iva,
                        v_fec_vigencia,
                        v_tip_valor,
                        v_tipo);

        -- existe impuesto, se genera movimiento
        v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.cod_usuario   := v_cod_usuario;
        r_gmovi.hora          := v_hora;
        r_gmovi.fecha         := p_fecha;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        --
        r_gmovi.cod_modulo      := r_pcta.cod_modulo;
        r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
        r_gmovi.cod_oficina     := r_pcta.cod_oficina;
        r_gmovi.nro_cuenta      := p_nro_cuenta;
        r_gmovi.cod_moneda      := r_pcta.cod_moneda;
        r_gmovi.fec_valor       := p_fecha;
        r_gmovi.cod_tra_padre   := 518;
        r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
        r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
        r_gmovi.cod_transaccion := 518;
        r_gmovi.monto           := r_pcta.mto_impuesto;
        r_gmovi.nro_documento   := null;
        r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'IVA s/ Comision';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_tasa        := v_cod_tasa;
        r_gmovi.val_tasa        := v_val_tas_iva;
        r_gmovi.cod_rubro       := null;
        r_gmovi.nro_caja        := null;
        r_gmovi.mto_equ_local   := round(trunc(nvl(r_pcta.mto_impuesto, 0),2) * v_cotizacion,0);

        -- inserto el registro de movimientos
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,v_es_nocturno);
      end if;

      --- cargos, para los que tienen comisión cargada
      prg_obt_cargos(p_cod_ofi_origen,
                p_nro_cuenta,
                r_pcta.cod_moneda,
                r_pcta.comision,
                r_pcta.cod_modulo,
                r_pcta.cod_modalidad,
                v_cod_tra_cargo,
                v_cod_tas_cargo,
                v_val_tas_cargo,
                v_val_cargo,
                v_cod_tra_impuesto,
                v_cod_tas_impuesto,
                v_val_tas_impuesto,
                v_val_impuesto);

      if v_val_cargo > 0 then
        -- existe cargo, se genera movimiento
        v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.cod_usuario   := v_cod_usuario;
        r_gmovi.hora          := v_hora;
        r_gmovi.fecha         := p_fecha;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        --
        r_gmovi.cod_modulo      := r_pcta.cod_modulo;
        r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
        r_gmovi.cod_oficina     := r_pcta.cod_oficina;
        r_gmovi.nro_cuenta      := p_nro_cuenta;
        r_gmovi.cod_moneda      := r_pcta.cod_moneda;
        r_gmovi.fec_valor       := p_fecha;
        r_gmovi.cod_tra_padre   := v_cod_tra_cargo;
        r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
        r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
        r_gmovi.cod_transaccion := v_cod_tra_cargo;
        r_gmovi.monto           := round(v_val_cargo,v_redondeo);
        r_gmovi.nro_documento   := null;
        r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'Comision por la Compra';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_tasa        := v_cod_tas_cargo;
        r_gmovi.val_tasa        := v_val_tas_cargo;
        r_gmovi.cod_rubro       := null;
        r_gmovi.nro_caja        := null;
        r_gmovi.mto_equ_local   := round(trunc(nvl(v_val_cargo, 0),2) * v_cotizacion,0);
        -- inserto el registro de movimientos
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,v_es_nocturno);
      end if;

      if v_val_impuesto > 0 then
        -- existe impuesto, se genera movimiento
        v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.cod_usuario   := v_cod_usuario;
        r_gmovi.hora          := v_hora;
        r_gmovi.fecha         := p_fecha;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        --
        r_gmovi.cod_modulo      := r_pcta.cod_modulo;
        r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
        r_gmovi.cod_oficina     := r_pcta.cod_oficina;
        r_gmovi.nro_cuenta      := p_nro_cuenta;
        r_gmovi.cod_moneda      := r_pcta.cod_moneda;
        r_gmovi.fec_valor       := p_fecha;
        r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
        r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
        r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
        r_gmovi.cod_transaccion := v_cod_tra_impuesto;
        r_gmovi.monto           := round(v_val_impuesto,v_redondeo);
        r_gmovi.nro_documento   := null;
        r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'IVA s/ Comision';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_tasa        := v_cod_tas_impuesto;
        r_gmovi.val_tasa        := v_val_tas_impuesto;
        r_gmovi.cod_rubro       := null;
        r_gmovi.nro_caja        := null;
        -- inserto el registro de movimientos
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,v_es_nocturno);
      end if;
      -- hago movimientos por la ganancia distribuida
      if r_pcta.cod_modalidad = 113 then
        -- existe distribucion de ganancia por el descuento
        v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.cod_usuario   := v_cod_usuario;
        r_gmovi.hora          := v_hora;
        r_gmovi.fecha         := p_fecha;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        --
        r_gmovi.cod_modulo      := r_pcta.cod_modulo;
        r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
        r_gmovi.cod_oficina     := r_pcta.cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := r_pcta.cod_moneda;
        r_gmovi.fec_valor       := p_fecha;
        r_gmovi.cod_tra_padre   := 720; -- transaccion de ganancia
        r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
        r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
        r_gmovi.cod_transaccion := 720;
        r_gmovi.monto           := nvl(r_pcta.mto_interes, 0) -
                          nvl(r_pcta.mto_ofi_interes, 0);
        r_gmovi.nro_documento   := null;
        r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'Ganancia por Interes';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_tasa        := null;
        r_gmovi.val_tasa        := null;
        r_gmovi.cod_rubro       := null;
        r_gmovi.nro_caja        := null;
        -- inserto el registro de movimientos
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,v_es_nocturno);
        --
        if r_pcta.mto_ofi_interes > 0 and
          r_pcta.cod_ofi_interes is not null then
          v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
          r_gmovi.cod_usuario   := v_cod_usuario;
          r_gmovi.hora          := v_hora;
          r_gmovi.fecha         := p_fecha;
          r_gmovi.nro_secuencia := v_nro_secuencia;
          r_gmovi.cod_oficina   := r_pcta.cod_ofi_interes;
          r_gmovi.monto         := nvl(r_pcta.mto_ofi_interes, 0);
          -- inserto el registro de movimientos
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,v_es_nocturno);
        end if;
      end if;
    end if;

    /*****************************************************************************/
    /*Insercion de Garantias*/
    /*****************************************************************************/
    if nvl(P_MTO_GARANTIA, 0) > 0 then
      -- se genera movimientos por la garantias
      for ga in garantias loop
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := p_fecha;
        r_gmovi.cod_modulo      := r_pcta.cod_modulo;
        r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
        r_gmovi.cod_oficina     := r_pcta.cod_oficina;
        r_gmovi.nro_cuenta      := p_nro_cuenta;
        r_gmovi.cod_moneda      := ga.cod_moneda;
        r_gmovi.est_cuenta      := null;
        r_gmovi.cod_tra_padre   := 360;
        r_gmovi.cod_transaccion := ga.cod_transaccion1;
        r_gmovi.monto           := ga.monto;
        r_gmovi.fec_valor       := p_fecha;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
        r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
        r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
        r_gmovi.nro_documento   := r_pcta.nro_cuenta;
        r_gmovi.concepto        := 'Garantia ' || ga.nro_garantia;
        --r_gmovi.cotizacion         := v_cotizacion;
        --r_gmovi.mto_equ_local      := round(trunc(v_capital,2)*v_cotizacion,0);
        pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
      end loop;
    end if;
    /*****************************************************************************/
    if r_pcta.estado = 'R' then
      --- Recupera datos de la Cuenta Repo
       pr_obt_datos(r_pcta.nro_cta_repo, r_ctarp);
      --- Generar movimiento de Repo
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      --ini AP 1880
      r_gmovi.cod_oficina     := r_ctarp.cod_oficina;
      r_gmovi.nro_cuenta      := r_ctarp.nro_cuenta;
      r_gmovi.cod_moneda      := r_ctarp.cod_moneda;
      --fin
      r_gmovi.cod_mod_padre   := r_ctarp.cod_modulo;
      r_gmovi.cod_mad_padre   := r_ctarp.cod_modalidad;
      r_gmovi.cod_tra_padre   := 101;
      --
      r_gmovi.cod_modulo      := r_ctarp.cod_modulo;
      r_gmovi.cod_modalidad   := r_ctarp.cod_modalidad;
      r_gmovi.cod_transaccion := 811;
      --
      r_gmovi.concepto        := 'Compra Repo';
      r_gmovi.nro_documento   := r_ctarp.nro_cuenta;
      --
      r_gmovi.monto           := r_ctarp.monto * -1;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(nvl(r_gmovi.monto,0) * nvl(v_cotizacion,0));
      --
      pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
      --
      --- Generar movimiento Interés Devengado Acumulado del Valor
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      --
      r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
      r_gmovi.cod_tra_padre   := 101;
      --
      r_gmovi.cod_modulo      := r_pcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
      r_gmovi.cod_transaccion := 813;
      --
      r_gmovi.concepto        := 'Compra Repo';
      r_gmovi.nro_documento   := r_ctarp.nro_cuenta;
      --
--      r_gmovi.monto           := r_ctarp.dev_acumulado*-1;
      r_gmovi.monto           := r_pcta.dev_acumulado*-1;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(nvl(r_gmovi.monto,0) * nvl(v_cotizacion,0));
      --
      pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
      --
      --- Generar movimiento Interés no Devengado
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.nro_cuenta      := r_pcta.nro_cuenta; -- AP 1880 El Int.No.Dev. de la cta RIPEADA
      r_gmovi.cod_oficina     := r_pcta.cod_oficina;-- oficina de la cta RIPEADA
      --
      r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
      r_gmovi.cod_tra_padre   := 101;
      --
      r_gmovi.cod_modulo      := r_pcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
      r_gmovi.cod_transaccion := 802;
      --
      r_gmovi.concepto        := 'Compra Repo';
      r_gmovi.nro_documento   := r_ctarp.nro_cuenta;
      r_gmovi.monto           := r_pcta.val_int_devengar * -1;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(nvl(r_gmovi.monto,0) * nvl(v_cotizacion,0));
      --
      pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
      --
      -- Reversión de los Intereses del Repo solo para estas modalidades Migradas.
      if r_pcta.cod_modalidad in (129,132,123) then
       -- Valor de la diferencia entre el interés Repo y el Devengado Acumulado. En el momento de la cancelación debe ser 0.
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_cuenta      := r_pcta.nro_cuenta;
        r_gmovi.cod_oficina     := r_pcta.cod_oficina;
        --
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_transaccion := 812;  -- INTERES REPO
        r_gmovi.concepto        := 'Interés Repo ';
        r_gmovi.monto           := (r_ctarp.mto_interes )* -1;
        r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion,0);
        --
        pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
      end if;
      -- Cancela la Cuenta Repo comprada.
      begin
        update md_cta_documentos
           set estado = 'N',
               cod_sit_contable = v_cod_sit_contable
         where nro_cuenta = r_ctarp.nro_cuenta;
      exception
        when others then
          raise_application_error (-20000,'Error al Modificar Cta. Repo. '||sqlerrm);
      end;
    end if;
    -- Si tiene estado Solicitado y Tiene Fecha Vencimiento Repo es una Compra con pacto de Reventa.
    if r_pcta.estado = 'S' and r_pcta.fec_ven_repo is not null then
      --- Generar movimiento de ReVenta
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.nro_cuenta      := r_pcta.nro_cuenta;
      r_gmovi.cod_oficina     := r_pcta.cod_oficina;
      --
      r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
      r_gmovi.cod_tra_padre   := 101;
      --
      r_gmovi.cod_modulo      := r_pcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
      r_gmovi.cod_transaccion := 814; -- Capital Título de Valor
      --
      r_gmovi.concepto        := 'Compra Pacto ReVenta';
      r_gmovi.nro_documento   := r_pcta.nro_cuenta;
      --
      r_gmovi.monto           := r_pcta.val_bas_repo;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(nvl(r_gmovi.monto,0) * nvl(v_cotizacion,0));
      --
      pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
   end if;
    --- Cargar variables de retorno
    p_nro_secuencia := v_nro_secuencia;

  END;
  --Obtener el monto de venta del documento
  PROCEDURE PR_OBT_MTO_VENTA(P_NRO_CUENTA  IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
                    P_MTO_COBRADO IN MD_CTA_DOCUMENTOS.SAL_VAL_PRESENTE%TYPE,
                    P_TOT_CAPITAL IN OUT MD_CTA_DOCUMENTOS.SAL_VAL_PRESENTE%TYPE,
                    P_TOT_INTERES IN OUT MD_CTA_DOCUMENTOS.SAL_INTERES%Type) IS

    r_docu md_cta_documentos%rowtype;
    --- Variables auxiliares
    v_sal_cobrado md_cta_documentos.sal_val_presente%type;
    v_sal_capital md_cta_documentos.sal_val_presente%type;
    v_sal_interes md_cta_documentos.sal_interes%type;
  BEGIN
    --- Recuperar datos del documento
    pam_doc.pr_obt_datos(p_nro_cuenta, r_docu);

    --- Monto cobrado
    v_sal_cobrado := p_mto_cobrado;
    --- Inicializar variables
    v_sal_capital := 0;
    v_sal_interes := 0;

    --- Recuperar saldo capital
    if r_docu.cod_modalidad = 113 then
      v_sal_capital := r_docu.sal_val_presente;
    else

      v_sal_capital := r_docu.sal_val_presente;
      --- Recuperar saldo interes
      v_sal_interes := r_docu.sal_interes;
    end if;

    --- Cargar parametros de salida
    p_tot_capital := v_sal_capital;
    p_tot_interes := v_sal_interes;
  END;

--Realiza la venta del documento
PROCEDURE PR_VTA_DOCUMENTO(P_NRO_CUENTA         IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
                  P_MTO_COBRADO        IN MD_CTA_DOCUMENTOS.MONTO%TYPE,
                  P_COD_OFI_ORIGEN     IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE,
                  P_CONCEPTO           IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
                  P_FECHA              IN GE_MOVIMIENTOS.FECHA%TYPE,
                  P_HORA               IN OUT GE_MOVIMIENTOS.HORA%TYPE,
                  P_NRO_SECUENCIA      IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%Type,
                  P_COD_TRA_PADRE      IN NUMBER default 999,
                  P_COD_MOD_PADRE      IN NUMBER,
                  P_COD_MAD_PADRE      IN Number,
                  P_MTO_GARANTIA       IN GE_MOVIMIENTOS.MONTO%TYPE Default Null,
                  p_MTO_INTERES        IN NUMBER Default Null,
                  p_MTO_INT_DESCONTADO IN NUMBER Default Null,
                  P_MTO_IMPUESTO       IN NUMBER Default Null,
                  P_MTO_CARGO          IN NUMBER Default Null,
                  P_TAS_VENTA          In MD_CTA_DOCUMENTOS.VAL_TASA%Type Default Null,
                  P_NRO_CUPON          IN NUMBER DEFAULT NULL,
                  P_EST_MOVIMIENTO     IN VARCHAR2 DEFAULT 'N') IS

  --- Datos del registros de cuentas
  r_docu         md_cta_documentos%rowtype;
  r_ctarep       md_cta_documentos%rowtype;
  r_gmovi        ge_movimientos%rowtype;
  v_sal_cobrado  pr_cuotas.sal_capital%type;
  v_sal_capital  pr_cuotas.sal_capital%type;
  v_sal_interes  pr_cuotas.sal_interes%type;
  v_int_cal      md_cta_documentos.mto_interes%Type;
  v_int_cobrado  md_doc_detalles.sal_interes%type;
  v_interes_cob  md_doc_detalles.sal_interes%type;
  v_interes_a    md_doc_detalles.sal_interes%type;
  v_capital_a    md_doc_detalles.sal_interes%Type; 
  v_tot_pag_cap  pr_cta_prestamos.sal_capital%type;
  v_pre_sal_cap  pr_cta_prestamos.sal_capital%type;
  v_resultado    md_cta_documentos.monto%Type;
  v_cod_sit_contable md_cta_documentos.cod_sit_contable%type;
  v_dia_interes  number;
  v_can_prestamo varchar2(01);
  v_redondeo     number;
  --- Variables de movimientos
  v_fecha              ge_movimientos.fecha%type;
  v_fec_actual         ge_movimientos.fecha%type;
  v_nro_secuencia      ge_movimientos.nro_secuencia%type;
  v_hora               ge_movimientos.hora%type;
  v_fec_ult_dev        pr_cta_prestamos.fec_ult_devengado%type;
  v_cotizacion         ge_movimientos.cotizacion%type;
  v_cod_transaccion    ge_movimientos.cod_transaccion%type;
  v_estado             varchar2(1);
  v_cod_tas_cargo      number;
  v_val_tas_cargo      number;
  v_val_cargo          number;
  v_cod_tra_impuesto   number;
  v_cod_tas_impuesto   number;
  v_val_tas_impuesto   number;
  v_val_impuesto       number;
  v_cod_tra_cargo      number := 704; ----------------- Transaccion por cargo
  v_tot_capital        number := 0;
  v_tot_interes        number := 0;
  v_tot_int_descontado number := 0;
  v_cap_amortizado     number := 0;
  v_int_amortizado     number := 0;
  v_int_descontado     number := 0;
  v_mto_capital        number := 0;
  --impuesto
  v_val_tas_iva  number;
  v_fec_vigencia date;
  v_tip_valor    ge_tasas.tip_valor%type;
  v_tipo         ge_tasas.tipo%type;
  v_cod_tasa     ge_tasas.cod_tasa%type;
  v_cancela      varchar2(1);
  v_cod_fli_error   NUMBER;
  v_des_fli_error   VARCHAR2(4000);
  v_monto_deseado   md_cta_documentos.monto%TYPE;
  --
  cursor cuotas is
    select *
      from md_doc_detalles
     where nro_cuenta = p_nro_cuenta
      and nro_cuota = nvl(p_nro_cupon,nro_cuota)
      and estado <> 'N'
     order by nro_cuota;

  --Desafectacion de Garantia
  cursor garantias is
    select a.nro_cuenta,
         a.nro_garantia,
         a.cod_garantia,
         nvl(a.cod_moneda, r_docu.cod_moneda) cod_moneda,
         nvl(p_mto_garantia, 0) monto,
         a.observacion,
         b.cod_transaccion2
      from pr_gar_tipos b, md_garantias a
     where a.nro_cuenta = p_nro_cuenta
      and b.cod_garantia = a.cod_garantia
      and b.cod_transaccion2 is not null
      and rownum = 1; -- ahora se desplica por el monto que dice en pantalla

BEGIN
  --- Recuperar datos del documento
  pam_doc.pr_obt_datos(p_nro_cuenta, r_docu);

  --- FIELDESK-159387 / MDD-128 — reasignacion FLI previa a venta
  --- Controles FLI/rest solo si se cobra el ultimo cupon (venta total).
  v_monto_deseado := NVL(p_mto_cobrado, 0);
  IF v_monto_deseado <= 0 THEN
    raise_application_error(-20000, 'Monto cobrado invalido');
  END IF;
  IF r_docu.monto IS NOT NULL AND v_monto_deseado > r_docu.monto THEN
    v_monto_deseado := r_docu.monto;
  END IF;
  IF fu_es_venta_documento(p_nro_cuenta, p_nro_cupon)
     AND fu_requiere_reasigna_fli(p_nro_cuenta,
                                  r_docu.nro_documento,
                                  v_monto_deseado,
                                  r_docu.sal_restringido) THEN
    pr_reasigna_reserva_fli(p_nro_cuenta,
                            v_monto_deseado,
                            v_cod_fli_error,
                            v_des_fli_error);
    IF v_cod_fli_error <> 0 THEN
      raise_application_error(-20000,
                              NVL(v_des_fli_error, 'Error reasignacion garantia FLI'));
    END IF;
  END IF;

  v_fec_ult_dev := nvl(r_docu.fec_ult_devengado, r_docu.fec_inicio);
  --- Inicializar datos del movimiento
  v_fecha      := p_fecha;
  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(10);

  v_hora          := nvl(p_hora, to_char(sysdate, 'HH24:MI:SS'));
  v_nro_secuencia := nvl(p_nro_secuencia, 0);

  --- Recuperar datos de la cuota
  v_sal_cobrado := p_mto_cobrado;
  v_tot_pag_cap := 0;

  --- Recuperar deuda de la cuota
  pam_doc.pr_obt_mto_venta(p_nro_cuenta,
                   v_sal_cobrado,
                   v_sal_capital,
                   v_sal_interes);
  -- Si es una cancelación carga la Variable.
  if translate(upper(p_concepto),'ÒÓ','OO') like 'CANCELACION DE DOCUMENTO %' then
    v_cancela := 'S';
  else
    v_cancela := 'N';
  end if;
  --validar monto cobrado, sólo call money tiene interés impuesto y cargos
  if r_docu.cod_modalidad in (110,116,146) OR FUM_OBT_OPE_REPO(r_docu.cod_modulo,r_docu.cod_modalidad,'S','O') = 'S' then -- Repo Otorgado
    -- 27.08.2009 FB: Modifico aqui para mad 110, esta validando contra el interes registrado siendo q al ser Vista el interes ingresa al momento de Venta/Cobro del Doc
    --if p_mto_cobrado > nvl(v_sal_capital, 0) + nvl(v_sal_interes, 0) +
    if p_mto_cobrado > nvl(v_sal_capital, 0) + nvl(p_MTO_INTERES, 0) +
      nvl(p_mto_cargo, 0) + nvl(p_mto_impuesto, 0) then
      raise_application_error(-20000, 'Monto a Cobrar es mayor al Capital + Interés + Cargos e Impuestos');
    end if;
  end if;

  --- Hallar el saldo capital
  v_pre_sal_cap := nvl(r_docu.sal_val_presente, 0) - nvl(v_tot_pag_cap, 0);

  --- Verificar si se calcula interes devengado
  if nvl(v_sal_interes, 0) > 0 and r_docu.cod_modalidad <> 113 Then
    --crédito tributario no devenga
    --- Si se paga interes
    if r_docu.cod_modalidad in (100,106,114,116,146,120,122,123,124,134,144,142,132,129) or
       r_docu.estado = 'R' or v_cancela = 'S' then
       -- Si es un Repo o una cancelación no devenga. el proceso de cancelación incluye el monto de todo lo devengado.
      null;
    else
      --las otras modalidades devengan
      pam_dev.PR_PRO_DEV_VTA_DOC(p_nro_cuenta,
                        v_fecha,
                        p_hora,
                        nvl(v_sal_interes, 0),
                        v_nro_secuencia);
    end if;
  end if;

  if v_pre_sal_cap - nvl(v_sal_capital, 0) > 0 then
    v_can_prestamo := 'N';
  else
    v_can_prestamo := 'S';
  end if;

  v_cotizacion := null;
  If r_docu.cod_moneda <> pag_gen.fu_obt_mon_local then
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                           10,
                           r_docu.cod_modalidad,
                           r_docu.cod_moneda);
  else
    v_redondeo := 0;
  End if;

  --Calcular el monto de la venta de acuerdo a la tasa de la venta
  v_dia_interes := r_docu.fec_vencimiento -
              nvl(r_docu.fec_ult_devengado + 1, v_fec_actual);

  --call money ya no calcula interés
  if r_docu.cod_modalidad not in (116,146) then
    If r_docu.tip_calculo = 'V' then
      v_int_cal := round((r_docu.monto * (P_TAS_VENTA / 36500) *
                   v_dia_interes),
                   v_redondeo);
    elsif r_docu.tip_calculo = 'A' then
      v_int_cal := nvl(r_docu.monto, 0) -
               Round(r_docu.monto /
                   (1 +
                   (P_TAS_VENTA * nvl(v_dia_interes, 0) / 36500)),
                   v_redondeo);
    elsif r_docu.tip_calculo = 'D' then
      --Directo adelantado
      v_int_cal := Round(r_docu.monto *
                   (P_TAS_VENTA / (100 + P_TAS_VENTA)),
                   v_redondeo);
    End if;

    if r_docu.cod_modalidad not in (110) AND FUM_OBT_OPE_REPO(r_docu.cod_modulo,r_docu.cod_modalidad,'S','O') = 'N' then -- Distinto Repo Otorgado
      --para call money el capital es el monto completo
      v_sal_capital := P_MTO_COBRADO;--r_docu.monto - v_int_cal;
    end if;
  end if;

  --Ganancia/Perdida
  if r_docu.cod_modalidad in (110,116,146) OR FUM_OBT_OPE_REPO(r_docu.cod_modulo,r_docu.cod_modalidad,'S','O') = 'S' OR v_cancela = 'S' then -- Repo Otorgado
    --call money o una cancelación no tiene ganancia ni pérdida
    v_resultado := 0;
  else
    v_resultado := nvl(v_sal_capital, 0) - nvl(r_docu.sal_val_presente, 0);
  end if;

  v_mto_capital := r_docu.sal_val_presente;
  -- Busca la situación contable del documentos antes de las modificaciones de estado
  -- Si el documento es un repo tiene estado R, sino tiene estado C.
  r_gmovi.cod_sit_contable := pab_asi.fu_cal_sit_contable(p_nro_cuenta);
  --
  if r_docu.estado <> 'R' then
  -- Si no es Repo hace las modificaciones.
    if r_docu.cod_modalidad in (110) OR FUM_OBT_OPE_REPO(r_docu.cod_modulo,r_docu.cod_modalidad,'S','O') = 'S' then  -- Repo Otorgado
      v_sal_capital := r_docu.sal_val_presente;
      if v_sal_capital = (nvl(p_mto_cobrado,0) - (nvl(p_mto_interes,0) + nvl(p_mto_impuesto,0) + nvl(p_mto_cargo,0))) then
        v_estado       := 'N';
        v_can_prestamo := 'S';
      else
        v_estado       := r_docu.estado;
        v_can_prestamo := 'N';
      end if;
      --- Actualizar maestro de documentos por credito tributario
      update md_cta_documentos
        set mto_venta        = nvl(mto_venta, 0) + nvl(p_mto_cobrado, 0),
           mto_int_venta    = 0,
           sal_val_presente = (nvl(sal_val_presente, 0) - nvl(p_mto_cobrado, 0))+ nvl(p_mto_cargo,0) + nvl(p_mto_impuesto,0) + nvl(p_mto_interes,0),
           sal_capital      = (nvl(sal_capital, 0) - nvl(p_mto_cobrado, 0)) + nvl(p_mto_cargo,0) + nvl(p_mto_impuesto,0) + nvl(p_mto_interes,0),
           sal_interes      = nvl(sal_interes,0) - nvl(p_mto_interes,0),
           estado           = v_estado,
           fec_cancelacion  = decode(estado, v_estado, null, p_fecha),
           fec_ult_pago = p_fecha
       where nro_cuenta = p_nro_cuenta;
    elsif r_docu.cod_modalidad = 113 then
      v_sal_capital := r_docu.sal_val_presente;
      if v_sal_capital < p_mto_cobrado then
        raise_application_error(-20000, 'Saldo inferior al monto cobrado');
      elsif v_sal_capital = p_mto_cobrado then
        v_estado       := 'N';
        v_can_prestamo := 'S';
      else
        v_estado       := r_docu.estado;
        v_can_prestamo := 'N';
      end if;
      --- Actualizar maestro de documentos por credito tributario
      update md_cta_documentos
        set mto_venta        = nvl(mto_venta, 0) + nvl(p_mto_cobrado, 0),
           mto_int_venta    = 0,
           sal_val_presente = nvl(sal_val_presente, 0) -
                        nvl(p_mto_cobrado, 0),
           sal_capital      = nvl(sal_capital, 0) - nvl(p_mto_cobrado, 0),
           sal_interes      = 0,
           estado           = v_estado,
           fec_cancelacion  = decode(estado, v_estado, null, p_fecha),
           fec_ult_pago = p_fecha
       where nro_cuenta = p_nro_cuenta;
    elsif r_docu.cod_modalidad in (106,114,134,144,142,132,129) then
      if p_mto_cobrado >=
        nvl(r_docu.sal_capital, 0) + nvl(r_docu.sal_interes, 0) then
        v_estado       := 'N';
        v_can_prestamo := 'S';
      else
        v_estado       := r_docu.estado;
        v_can_prestamo := 'N';
      end if;
      -- actualizo los saldos
      v_mto_capital := (nvl(p_mto_cobrado, 0) - nvl(p_mto_interes, 0));
      update md_cta_documentos
        set sal_capital      = nvl(sal_capital, 0) -
                        (nvl(p_mto_cobrado, 0) -
                        nvl(p_mto_interes, 0)),
           sal_interes      = nvl(sal_interes, 0) - nvl(p_mto_interes, 0),
           estado           = v_estado,
           sal_val_presente = nvl(sal_val_presente, 0) -
                        nvl(v_mto_capital, 0),
           fec_ult_pago = p_fecha
       where nro_cuenta = p_nro_cuenta;

      v_resultado   := 0;
      v_sal_capital := 0;
    elsif r_docu.cod_modalidad in (116,146) then
      v_sal_capital := r_docu.sal_val_presente;
      if v_sal_capital = (p_mto_cobrado-(nvl(p_mto_interes,0) + nvl(p_mto_impuesto,0) + nvl(p_mto_cargo,0))) then
        v_estado       := 'N';
        v_can_prestamo := 'S';
      else
        v_estado       := r_docu.estado;
        v_can_prestamo := 'N';
      end if;

      --- Actualizar maestro de documentos
      update md_cta_documentos
        set mto_venta        = nvl(p_mto_cobrado,0)-(nvl(p_mto_impuesto,0) + nvl(p_mto_cargo,0)),
           mto_int_venta    = nvl(p_MTO_INTERES, 0),
           sal_val_presente = (nvl(sal_val_presente,0) + nvl(p_mto_impuesto,0) + nvl(p_mto_cargo,0) + nvl(p_mto_interes,0)) - nvl(p_mto_cobrado,0),
            val_presente = (nvl(sal_val_presente,0) + nvl(p_mto_impuesto,0) + nvl(p_mto_cargo,0) + nvl(p_mto_interes,0)) - nvl(p_mto_cobrado,0),
           sal_interes      = nvl(sal_interes,0)-(nvl(p_mto_interes,0) + nvl(p_mto_int_descontado,0)),
           sal_capital      = (nvl(sal_capital,0) + nvl(p_mto_impuesto,0) + nvl(p_mto_cargo,0) + nvl(p_mto_interes,0)) - p_mto_cobrado,
           estado           = v_estado,
           fec_cancelacion  = p_fecha,
           mto_impuesto     = nvl(p_mto_impuesto,0),
           fec_ult_pago     = p_fecha,
           val_int_devengar = nvl(val_int_devengar,0) - nvl(p_mto_int_descontado,0)
       where nro_cuenta = p_nro_cuenta;
    elsif r_docu.cod_modalidad in (100,120,122,123,124) then
      if p_mto_cobrado + nvl(p_mto_int_descontado,0) >=
        nvl(r_docu.sal_capital, 0) + nvl(r_docu.sal_interes, 0) then
        v_estado       := 'N';
        v_can_prestamo := 'S';
      else
        v_estado       := r_docu.estado;
        v_can_prestamo := 'N';
      end if;

      -- actualizo los saldos 
      v_mto_capital := (nvl(p_mto_cobrado, 0) - (nvl(p_mto_interes, 0)- nvl(p_mto_int_descontado, 0)));
      if v_mto_capital < 0 then --Significa que esta cobrando solo los intereses
         v_mto_capital := 0;
      end if;
      ---tener en cuenta los pagos parciales
      if nvl(p_mto_cobrado,0) + nvl(p_mto_int_descontado,0) >= nvl(p_mto_interes, 0) then
         v_interes_cob := nvl(p_mto_interes, 0);
      elsif nvl(p_mto_cobrado,0) + nvl(p_mto_int_descontado,0) < nvl(p_mto_interes, 0)  then
        v_interes_cob := nvl(p_mto_cobrado,0) +  nvl(p_mto_int_descontado,0) ;
      else
        v_interes_cob := nvl(p_mto_interes, 0);
      end if;

      update md_cta_documentos
        set sal_capital  =
                      CASE  WHEN nvl(sal_capital,  0) >  nvl(v_mto_capital,0)  THEN nvl(sal_capital, 0) - nvl(v_mto_capital,0)   
                            WHEN nvl(v_mto_capital,0) >  nvl(sal_capital, 0)   THEN nvl(sal_capital, 0) - nvl(sal_capital, 0) 
                      END,                    
           sal_interes      = nvl(sal_interes, 0) - nvl(v_interes_cob,0) /* nvl(p_mto_interes, 0)*/,
           estado           = v_estado,
           sal_val_presente =
           CASE  WHEN nvl(sal_val_presente,  0) >  nvl(v_mto_capital,0)  THEN nvl(sal_val_presente, 0) - nvl(v_mto_capital,0)   
                 WHEN nvl(v_mto_capital,0) >  nvl(sal_val_presente, 0)   THEN nvl(sal_val_presente, 0) - nvl(sal_val_presente, 0) 
                 END,
           fec_ult_pago = p_fecha
       where nro_cuenta = p_nro_cuenta;

      v_resultado   := 0;
      v_sal_capital := 0;
    else
      --- Actualizar maestro de documentos
      update md_cta_documentos
        set mto_venta        = nvl(v_sal_capital, 0),
           mto_int_venta    = decode(r_docu.cod_modalidad,
                            110,
                            nvl(p_MTO_INTERES, 0),
                            nvl(v_int_cal, 0)), --call money recibe el interés
           sal_val_presente = 0,
           sal_interes      = 0,
           estado           = 'N',
           fec_cancelacion  = p_fecha,
           mto_impuesto     = decode(r_docu.cod_modalidad,
                            110,
                            p_mto_impuesto,
                            mto_impuesto),
           fec_ult_pago = p_fecha
       where nro_cuenta = p_nro_cuenta;
    end if;
  end if;
  --
  if r_docu.estado = 'R' then
    -- Si es un Repo carga la situación contable oorrespondiente del Movimiento.
    v_cod_sit_contable := r_gmovi.cod_sit_contable;
    v_can_prestamo := 'N';
    -- Actualiza Situación Contable del Repo, tiene la misma situación que el estado Ripeado.
    update md_cta_documentos m
       set cod_sit_contable = v_cod_sit_contable
     where nro_cuenta = r_docu.nro_cta_repo;
  else
    -- Si no carga la situación contable "Normal".
    v_cod_sit_contable := pab_asi.fu_cal_sit_contable(p_nro_cuenta);
  end if;
  --
  update md_cta_documentos m
     set cod_sit_contable = v_cod_sit_contable
   where nro_cuenta = p_nro_cuenta;
  --- GENERAR MOVIMIENTOS
  r_gmovi.cod_usuario    := User;
  r_gmovi.hora           := v_hora;
  r_gmovi.fecha          := PAG_CAL.FU_OBT_FEC_ACTUAL(10);
  r_gmovi.cod_modulo     := r_docu.cod_modulo;
  r_gmovi.cod_modalidad  := r_docu.cod_modalidad;
  r_gmovi.cod_oficina    := r_docu.cod_oficina;
  r_gmovi.nro_cuenta     := p_nro_cuenta;
  r_gmovi.cod_moneda     := r_docu.cod_moneda;
  r_gmovi.est_cuenta     := null; -- r_docu.estado; no es cambio de estado
  r_gmovi.cod_tra_padre  := p_cod_tra_padre;
  r_gmovi.cod_mod_padre  := p_cod_mod_padre;
  r_gmovi.cod_mad_padre  := p_cod_mad_padre;
  r_gmovi.fec_valor      := p_fecha;
  r_gmovi.reversado      := 'N';
  r_gmovi.protegido      := 'N';
  --r_gmovi.estado         := 'N';
  r_gmovi.estado         := p_est_movimiento; -- JIRA 3389
  r_gmovi.cod_ofi_origen := p_cod_ofi_origen;
  r_gmovi.nro_documento  := p_nro_cuenta;
  r_gmovi.referencia     := r_docu.nro_documento;
  r_gmovi.concepto       := nvl(p_concepto, 'Venta de Documento');

  if r_docu.cod_modalidad = 113 then
    -- credito tributario
    IF p_mto_cobrado > 0 THEN
      -- Valor de la venta
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.cod_transaccion := 821; -- No afecta
      r_gmovi.monto           := p_mto_cobrado;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END IF;

  else
    IF v_sal_Capital > 0 and r_docu.cod_modalidad not in (110,116,146) and FUM_OBT_OPE_REPO(r_docu.cod_modulo,r_docu.cod_modalidad,'S','O') = 'N' THEN --Distinto Repo Otorgado
      -- Valor de la venta
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.cod_transaccion := 821; -- No afecta
      r_gmovi.monto           := v_sal_Capital;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END IF;

    IF v_mto_capital > 0 and r_docu.cod_modalidad not in (100,120,122,123,124) THEN
      -- Valor presente actual
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.cod_transaccion := 801; -- Afecta Capital
      r_gmovi.monto           := v_mto_capital;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      r_gmovi.nro_documento3  := p_nro_cupon;
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    elsif v_mto_capital > 0 and r_docu.cod_modalidad in (100,120,122,123,124) THEN
      -- Valor presente actual
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.cod_transaccion := 801; -- Afecta Capital
      r_gmovi.monto           := v_mto_capital;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      r_gmovi.nro_documento3  := p_nro_cupon;
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END IF;

    IF v_resultado <> 0 THEN
      -- Ganancia/Perdida
      if v_resultado < 0 then
        v_cod_transaccion := 159;
      else
        v_cod_transaccion := 158;
      end if;
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.cod_transaccion := v_cod_transaccion;
      r_gmovi.monto           := abs(v_resultado);
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END IF;
    ---se generan datos de cobro de intereses
    If r_docu.val_int_devengar > 0 and
      --(r_docu.cod_modalidad <> 114 or
      --(r_docu.cod_modalidad = 114 and v_can_prestamo = 'S')) then
      (r_docu.cod_modalidad not in (100,106,114,120,122,123,124,134,144,142,132,129) or
         (r_docu.cod_modalidad in (100,106,114,120,122,123,124,134,144,142,132,129) and v_can_prestamo = 'S')) then
      --- Interes a Devengar
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.cod_transaccion := 802; -- No afecta
      r_gmovi.monto           := r_docu.val_int_devengar;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;

    --if r_docu.cod_modalidad not in (110,114,116) then
    if r_docu.cod_modalidad not in (100,110,106,114,116,146,120,122,123,124,134,144,142,132,129) and FUM_OBT_OPE_REPO(r_docu.cod_modulo,r_docu.cod_modalidad,'S','O') = 'N' then -- Distinto Repo Otorgado
      If nvl(r_docu.monto, 0) - nvl(r_docu.mto_interes, 0) > 0 then
        --- Valor de la Compra - inserta capital original de la compra
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.cod_transaccion := 805; -- No afecta
        r_gmovi.monto           := nvl(r_docu.monto, 0) -
                          nvl(r_docu.mto_interes, 0);
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;

      If nvl(r_docu.mto_interes, 0) > 0  then
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.cod_transaccion := 817; -- Afecta Interes
        r_gmovi.monto           := nvl(r_docu.mto_interes, 0);
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;
    else
      --call money  -- Repo Otorgado
      if nvl(p_mto_interes, 0) > 0 and r_docu.cod_modalidad not in (100,120,122,123,124) then
        --- Interes calculado en el cobro
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.cod_transaccion := 817; -- Afecta Interes
        r_gmovi.monto           := nvl(p_mto_interes, 0);
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
        r_gmovi.nro_documento3  := p_nro_cupon;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      elsif nvl(p_mto_interes, 0) > 0 and r_docu.cod_modalidad in (100,120,122,123,124) then
        --esta seccion tiene en cuenta los pagos parciales donde es solo interes lo que cobra
        if  nvl(v_sal_capital,0) = 0 and nvl(p_mto_interes,0) > 0  then
          if  ( nvl(p_mto_cobrado, 0)  <=  nvl(p_mto_interes, 0) )  then
             v_int_cobrado := nvl(p_mto_cobrado, 0)  ;   
          else
             v_int_cobrado := nvl(p_mto_interes, 0)- nvl(p_mto_int_descontado, 0) ;           
          end if;
        else
           v_int_cobrado := nvl(p_mto_interes, 0)- nvl(p_mto_int_descontado, 0) ;           
        end if;
        --- Interes calculado en el cobro
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.cod_transaccion := 817; -- Afecta Interes
        r_gmovi.monto           := v_int_cobrado ;
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
        r_gmovi.nro_documento3  := p_nro_cupon;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;

      If nvl(p_mto_impuesto, 0) > 0 and r_docu.cod_modalidad not in (106,114,134,144,142,132,129) then
        --recupera tasa
        pag_gen.pr_obt_val_tasa(r_docu.cod_modulo,
                        r_docu.cod_modalidad,
                        r_docu.cod_oficina,
                        r_docu.nro_cuenta,
                        r_docu.cod_moneda,
                        p_mto_impuesto,
                        'N',
                        v_cod_tasa,
                        518, --Transaccion de iva 5%
                        p_fecha,
                        v_val_tas_iva,
                        v_fec_vigencia,
                        v_tip_valor,
                        v_tipo);

        --- Impuesto sobre el interés, call money es el único que tiene
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.emi_aviso       := 'S';
        r_gmovi.cod_transaccion := 518; -- Iva sobre interés
        r_gmovi.monto           := nvl(p_mto_impuesto, 0);
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
        r_gmovi.cod_tasa        := v_cod_tasa;
        r_gmovi.val_tasa        := v_val_tas_iva;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;

      --limpiar
      r_gmovi.cod_tasa := null;
      r_gmovi.val_tasa := null;
      --cargo e impuesto
      If nvl(p_mto_cargo, 0) > 0 then
        prg_obt_cargos(p_cod_ofi_origen,
                  p_nro_cuenta,
                  r_docu.cod_moneda,
                  p_mto_cargo,
                  r_docu.cod_modulo,
                  r_docu.cod_modalidad,
                  v_cod_tra_cargo,
                  v_cod_tas_cargo,
                  v_val_tas_cargo,
                  v_val_cargo,
                  v_cod_tra_impuesto,
                  v_cod_tas_impuesto,
                  v_val_tas_impuesto,
                  v_val_impuesto);

        if v_val_cargo > 0 then
          -- existe cargo, se genera movimiento
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_transaccion := v_cod_tra_cargo;
          r_gmovi.monto           := v_val_cargo;
          r_gmovi.nro_documento   := null;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'Cargo por la Venta';
          r_gmovi.cod_tasa        := v_cod_tas_cargo;
          r_gmovi.val_tasa        := v_val_tas_cargo;
          r_gmovi.cod_rubro       := null;
          r_gmovi.nro_caja        := null;
          r_gmovi.cotizacion      := v_cotizacion;
          r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion,0);
          -- inserto el registro de movimientos
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
        end if;

        if v_val_impuesto > 0 then
          -- existe impuesto, se genera movimiento
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_transaccion := v_cod_tra_impuesto;
          r_gmovi.monto           := v_val_impuesto;
          r_gmovi.nro_documento   := null;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'IVA s/ Cargo';
          r_gmovi.cod_tasa        := v_cod_tas_impuesto;
          r_gmovi.val_tasa        := v_val_tas_impuesto;
          r_gmovi.cod_rubro       := null;
          r_gmovi.nro_caja        := null;
          r_gmovi.cotizacion      := v_cotizacion;
          r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion,0);
          -- inserto el registro de movimientos
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
        end if;
      end if; --cargo
    end if; --modalidad
  end if;
  --limpiar
  r_gmovi.cod_tasa := null;
  r_gmovi.val_tasa := null;

  --- Generar movimiento del cambio de estado a cancelado
  if v_can_prestamo = 'S' then
    v_nro_secuencia             := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia       := v_nro_secuencia;
    r_gmovi.emi_aviso           := 'N';
    r_gmovi.cod_transaccion     := 429;
    --r_gmovi.est_cuenta          := 'N';
    r_gmovi.est_cuenta          := NULL; --JIRA 3389
    r_gmovi.concepto            := 'Canc. x Venta/Cobro';
    r_gmovi.monto               := null;
    r_gmovi.cotizacion          := null;
    r_gmovi.mto_equ_local       := null;
    r_gmovi.cod_usu_autorizador := null;
    r_gmovi.cod_autorizacion    := null;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
  end if;

  -- tiene cupones
  --  if r_docu.cod_modalidad = 114 then
  if r_docu.cod_modalidad in (100,106,114,120,122,123,124,134,144,142,132,129) then
    --capital amortizado
    v_tot_capital := (nvl(p_mto_cobrado, 0) - (nvl(p_mto_interes, 0)- nvl(p_mto_int_descontado, 0)));
    --interes amortizado
    v_tot_interes := (nvl(p_mto_interes, 0)- nvl(p_mto_int_descontado, 0));
    --interes descontado
    v_tot_int_descontado := nvl(p_mto_int_descontado, 0);
    for ct in cuotas loop
      -- Carga las variables is es una venta del Documento y sus Cupones.
      if p_nro_cupon is null then
        v_tot_interes := ct.sal_interes;
        v_tot_capital := ct.sal_capital;
      end if;
      -- capital de la cuota
      if v_tot_capital > ct.sal_capital then
        v_cap_amortizado := ct.sal_capital;
      else
        v_cap_amortizado := v_tot_capital;
      end if;
      
      
      ---Tener en cuenta cupones en donde en el detalle tiene sal_capital 0, y solo hay sal_interes
      if  ct.sal_capital > 0  then
        v_capital_a := v_cap_amortizado;
      else  
        v_capital_a := 0;
      end if; 
        
      --v_tot_capital := nvl(v_tot_capital, 0) - v_cap_amortizado;
      -- interes amortizado de la cuota
      if v_tot_interes > ct.sal_interes then
        v_int_amortizado := ct.sal_interes;
      else
        v_int_amortizado := v_tot_interes;
        -- ya se cobro todo el interes, puede que el resto sea descontado
        if v_tot_int_descontado > (ct.sal_interes - v_int_amortizado) then
          v_int_descontado := (ct.sal_interes - v_int_amortizado);
        else
          v_int_descontado := v_tot_int_descontado;
        end if;
        --v_tot_int_descontado := nvl(v_tot_int_descontado, 0) - v_int_descontado;
      end if;
      
      --Se transpasa  a una variable, en esta caso a v_interes_a y se tiene en cuenta 
      --los saldos solo de intereses en el detalle y no tiene saldo de capital
      v_interes_a := v_int_amortizado ;
      if  ct.sal_capital = 0 and ct.sal_interes > 0  then
        if   nvl(p_mto_cobrado, 0) <   nvl(p_mto_interes, 0) then
          v_interes_a := nvl(p_mto_cobrado, 0) ;
        end if;
      end if;      
      --v_tot_interes := nvl(v_tot_interes, 0) - v_int_amortizado;
      -- ya tengo los datos por cuota
      if nvl(v_cap_amortizado, 0) + nvl(v_int_amortizado, 0) +
        nvl(v_int_descontado, 0) >=
        nvl(ct.sal_capital, 0) + nvl(ct.sal_interes, 0) or
        p_nro_cupon is null then -- Si es una cancelación masiva no
        -- cambio de estado
        v_estado := 'N';
      else
        v_estado := ct.estado;
      end if;
      -- actualizo los datos
      update md_doc_detalles
        set estado             = v_estado,
           sal_capital        = nvl(sal_capital, 0) -
                         nvl(v_capital_a, 0),
           sal_interes        = nvl(sal_interes, 0) -
                         (nvl(v_interes_a, 0) +
                          nvl(v_int_descontado, 0)),
           mto_int_descontado = nvl(mto_int_descontado, 0) +
                         nvl(v_int_descontado, 0),
           fec_ult_pago       = p_fecha
       where nro_cuenta = ct.nro_cuenta
        and nro_cuota = ct.nro_cuota;
    end loop;
  end if;

  -- se genera movimientos por la garantias
  if nvl(P_MTO_GARANTIA, 0) > 0 then
    for ga in garantias loop
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := user;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := p_fecha;
      r_gmovi.cod_modulo      := r_docu.cod_modulo;
      r_gmovi.cod_modalidad   := r_docu.cod_modalidad;
      r_gmovi.cod_oficina     := r_docu.cod_oficina;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.cod_moneda      := ga.cod_moneda;
      r_gmovi.est_cuenta      := null;
      r_gmovi.cod_tra_padre   := 360;
      r_gmovi.cod_transaccion := ga.cod_transaccion2;
      r_gmovi.monto           := ga.monto;
      r_gmovi.fec_valor       := p_fecha;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      --r_gmovi.estado          := 'N';
      r_gmovi.estado          := p_est_movimiento; -- JIRA 3389
      r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
      r_gmovi.cod_mod_padre   := r_docu.cod_modulo;
      r_gmovi.cod_mad_padre   := r_docu.cod_modalidad;
      r_gmovi.nro_documento   := r_docu.nro_cuenta;
      r_gmovi.concepto        := 'Garantia ' || ga.nro_garantia;
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end loop;
  end if;

  -- genero los movimientos por el interes descontado
  if p_mto_int_descontado > 0 then
    v_nro_secuencia         := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.fecha           := p_fecha;
    r_gmovi.cod_modulo      := r_docu.cod_modulo;
    r_gmovi.cod_modalidad   := r_docu.cod_modalidad;
    r_gmovi.cod_oficina     := r_docu.cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := r_docu.cod_moneda;
    r_gmovi.cod_tra_padre   := 360;
    r_gmovi.cod_transaccion := 803;
    r_gmovi.concepto        := 'Int. Descontado ' || p_nro_cuenta;
    r_gmovi.monto           := nvl(p_mto_int_descontado, 0);
    r_gmovi.fec_valor       := p_fecha;
    r_gmovi.emi_aviso       := 'S';
    r_gmovi.reversado       := 'N';
    r_gmovi.protegido       := 'N';
    --r_gmovi.estado          := 'N';
    r_gmovi.estado          := p_est_movimiento; -- JIRA 3389
    r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
    r_gmovi.cod_mod_padre   := r_docu.cod_modulo;
    r_gmovi.cod_mad_padre   := r_docu.cod_modalidad;
    r_gmovi.nro_documento   := r_docu.nro_cuenta;
    r_gmovi.cotizacion      := v_cotizacion;
    r_gmovi.cod_tasa        := null;
    r_gmovi.val_tasa        := null;
    r_gmovi.mto_equ_local   := round(trunc(nvl(p_mto_int_descontado, 0), 2) *
                      v_cotizacion,0);
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
  end if;
  -- Si es un Repo genera los movimientos correspondientes
  if r_docu.estado = 'R' then
    -- Recupera datos de la Cuenta Repo.
    pam_doc.pr_obt_datos(r_docu.nro_cta_repo, r_ctarep);
    --
    v_nro_secuencia         := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.fecha           := p_fecha;
    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_mod_padre   := p_cod_mod_padre;
    r_gmovi.cod_mad_padre   := p_cod_mad_padre;
    r_gmovi.cod_modulo      := r_ctarep.cod_modulo;
    r_gmovi.cod_modalidad   := r_ctarep.cod_modalidad;
    r_gmovi.cod_transaccion := 811;  -- VENTA REPO
    r_gmovi.cod_oficina     := r_ctarep.cod_oficina;
    r_gmovi.nro_cuenta      := r_ctarep.nro_cuenta;
    r_gmovi.cod_moneda      := r_ctarep.cod_moneda;
    r_gmovi.concepto        := 'Venta Repo ' || r_ctarep.nro_cuenta;
    r_gmovi.monto           := r_ctarep.monto;
    r_gmovi.cotizacion      := v_cotizacion;
    r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion,0);
    r_gmovi.fec_valor       := p_fecha;
    r_gmovi.emi_aviso       := 'S';
    r_gmovi.reversado       := 'N';
    r_gmovi.protegido       := 'N';
    --r_gmovi.estado          := 'N';
    r_gmovi.estado          := p_est_movimiento; -- JIRA 3389
    r_gmovi.est_cuenta      := null;
    r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
    r_gmovi.nro_documento   := r_ctarep.nro_cuenta;
    r_gmovi.cod_tasa        := null;
    r_gmovi.val_tasa        := null;
    --
    pag_gen.pr_ins_ge_movimiento(r_gmovi);

    -- Valor interés Repo
    v_nro_secuencia         := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_transaccion := 812;  -- INTERES REPO
    r_gmovi.concepto        := 'Interés Repo ' || r_ctarep.nro_cuenta;
    r_gmovi.monto           := r_ctarep.mto_interes;
    r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion,0);
    --
    pag_gen.pr_ins_ge_movimiento(r_gmovi);

    -- Traslado de Devengado Acumulado
    v_nro_secuencia         := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_transaccion := 813;  -- INTERES DEL VALOR
    r_gmovi.concepto        := 'Devengado Acumulado ' || r_docu.nro_cuenta;
    r_gmovi.monto           := r_docu.dev_acumulado;
    r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion,0);
    --
    pag_gen.pr_ins_ge_movimiento(r_gmovi);

  end if;
  -- Si es un Contrato de Compra con Pacto de Reventa
  if r_docu.estado = 'C' and r_docu.fec_ven_repo is not null then
    v_nro_secuencia         := v_nro_secuencia + 1;
    --
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.fecha           := p_fecha;
    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_mod_padre   := p_cod_mod_padre;
    r_gmovi.cod_mad_padre   := p_cod_mad_padre;
    r_gmovi.cod_modulo      := r_docu.cod_modulo;
    r_gmovi.cod_modalidad   := r_docu.cod_modalidad;
    r_gmovi.cod_transaccion := 814;  -- Capital Título de Valor
    r_gmovi.cod_oficina     := r_docu.cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := r_docu.cod_moneda;
    r_gmovi.concepto        := 'Venta Título ' || p_nro_cuenta;
    r_gmovi.monto           := nvl(r_docu.val_bas_repo,0)*-1;
    r_gmovi.cotizacion      := v_cotizacion;
    r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion,0);
    r_gmovi.fec_valor       := p_fecha;
    r_gmovi.emi_aviso       := 'S';
    r_gmovi.reversado       := 'N';
    r_gmovi.protegido       := 'N';
    --r_gmovi.estado          := 'N';
    r_gmovi.estado          := p_est_movimiento; -- JIRA 3389
    r_gmovi.est_cuenta      := null;
    r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
    r_gmovi.nro_documento   := r_docu.nro_cuenta;
    r_gmovi.cod_tasa        := null;
    r_gmovi.val_tasa        := null;
    --
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
  end if;
  p_nro_secuencia := v_nro_secuencia;
END;
  /* Obtener tasa efectiva y nominal del documento */
  PROCEDURE PR_OBT_TAS_DOCUMENTO(P_NRO_CUENTA IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
                       P_VAL_TAE    IN OUT NUMBER,
                       P_VAL_TAN    IN OUT NUMBER) IS

    v_acum_tan number;
    v_acum_tae number;
    v_contador number;
    --v_gastos_imp  number;
    --v_gastos_noi  number;
    --v_avg_dia     number;
    --v_dif_cuotas  number;
    v_dif_permitida number := 1000;
    --v_per_capital number;
    v_dias       number;
    v_dias_cuota number;
    --v_pri_cuota   number;
    --v_min_cuota   number;
    v_tot_dias number;
    --v_mto_gasto   number(18,2);
    v_cod_moneda        ge_cuentas.cod_moneda%type;
    v_mto_capital       pr_cta_prestamos.mto_capital%type;
    v_mto_desembolso    pr_cta_prestamos.monto%type;
    v_sal_capital       pr_cta_prestamos.mto_capital%type;
    v_fec_inicio        pr_cta_prestamos.fec_inicio%type;
    v_fec_vencimiento   pr_solicitudes.fec_vencimiento%type;
    v_fec_vto_cuota_ant pr_sol_cuotas.fec_vto_exacto%type;
    v_plazo             number;
    --v_can_cuotas      number;
    v_numero          varchar2(3000);
    v_auxiliar        varchar2(3000);
    v_val_inicial     pr_cta_prestamos.mto_capital%type;
    v_tip_interes     pr_solicitudes.tip_interes%type;
    v_val_tas_pactada number;
    --v_tip_amortizacion varchar2(1);
    --v_tipo             varchar2(1);
    v_redondeo           number(2) := 0;
    v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;
    --- Cursor de documentos
    cursor c_documentos is
      select nvl(val_presente, 0) + nvl(mto_interes, 0) val_documento,
           nvl(val_presente, 0) mto_capital,
           nvl(mto_interes, 0) mto_interes,
           trunc(fec_vencimiento - v_fec_inicio) dias,
           trunc(fec_vencimiento - v_fec_inicio) dia_interes,
           trunc(fec_vencimiento) fec_vto_exacto
        from md_cta_documentos
       where nro_cuenta = p_nro_cuenta
       order by 1;

    /* Obtener datos del documento. */
    PROCEDURE LP_OBT_DAT_DOCUMENTO(P_NRO_CUENTA      In MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
                         P_COD_MONEDA      IN OUT MD_CTA_DOCUMENTOS.COD_MONEDA%TYPE,
                         P_MTO_CAPITAL     IN OUT MD_CTA_DOCUMENTOS.MONTO%TYPE,
                         P_TIP_INTERES     IN OUT MD_CTA_DOCUMENTOS.TIP_CALCULO%TYPE,
                         P_FEC_INICIO      IN OUT DATE,
                         P_FEC_VENCIMIENTO IN OUT DATE,
                         P_VAL_TASA        IN OUT NUMBER,
                         P_MTO_DESEMBOLSO  IN OUT PR_SOLICITUDES.MONTO%TYPE) IS
    BEGIN
      select a.cod_moneda,
           a.val_presente,
           a.tip_calculo,
           a.fec_inicio,
           a.fec_vencimiento,
           a.val_tasa,
           a.val_presente
        into p_cod_moneda,
           p_mto_capital,
           p_tip_interes,
           p_fec_inicio,
           p_fec_vencimiento,
           p_val_tasa,
           p_mto_desembolso
        from md_cta_documentos a
       where a.nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        raise_application_error(-20000,
                        'Cuenta ' || p_nro_cuenta ||
                        ' no registrada');
    END;
  BEGIN
    v_contador := 0;
    v_acum_tan := 0;
    v_acum_tae := 0;
    --- Obtener datos del documento
    lp_obt_dat_documento(p_nro_cuenta,
                  v_cod_moneda,
                  v_mto_capital,
                  v_tip_interes,
                  v_fec_inicio,
                  v_fec_vencimiento,
                  v_val_tas_pactada,
                  v_mto_desembolso);

    v_sal_capital       := v_mto_capital;
    v_plazo             := v_fec_vencimiento - v_fec_inicio;
    v_fec_vto_cuota_ant := v_fec_inicio;
    v_redondeo          := 0;
    if v_cod_moneda = pag_gen.fu_obt_mon_local then
      v_dif_permitida := 1000;
    else
      v_dif_permitida := 10;
      v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6);
    end if;
    for doc in c_documentos loop
      v_numero := doc.val_documento;

      If v_tip_interes = 'A' then
        -- Si es adelantado...
        v_tot_dias    := nvl(v_tot_dias, 0) + doc.dia_interes;
        v_dias_cuota  := doc.fec_vto_exacto - v_fec_vto_cuota_ant;
        v_val_inicial := doc.mto_capital;
        v_numero      := doc.val_documento;
        v_dias        := doc.dias;
      End If;
      --
      if v_tip_interes != 'A' then
        v_dias        := doc.dia_interes;
        v_val_inicial := v_sal_capital;
        v_auxiliar    := v_sal_capital + doc.mto_interes;
        v_numero      := v_auxiliar;
      end if;
      --- Hace los calculos de TIR, TAN y TAE
      DECLARE
        v_tir     number;
        v_tan     number;
        v_tae     number;
        v_dias1   number(4);
        v_inicial number(18, 2);
        v_numero1 varchar2(3000);
      BEGIN
        v_dias1   := v_dias;
        v_numero1 := v_numero;
        v_inicial := v_val_inicial;
        if v_inicial > 0 then
          v_tir := pas_bcp.fu_obt_tir(v_inicial, 1, v_numero1);
          v_tan := pas_bcp.fu_obt_tas_anual(v_tir, v_dias);
          v_tae := pas_bcp.fu_obt_tae(v_tan, v_dias);
        else
          v_tir := 0;
          v_tan := 0;
          v_tae := 0;
        end if;
        v_acum_tan := nvl(v_acum_tan, 0) + nvl(v_tan, 0);
        v_acum_tae := nvl(v_acum_tae, 0) + nvl(v_tae, 0);
      END;
      v_sal_capital       := v_sal_capital - doc.mto_capital;
      v_fec_vto_cuota_ant := doc.fec_vto_exacto;
      v_contador          := v_contador + 1;
    end loop;
    --- Calcular tasa promedio
    p_val_tan := round(v_acum_tan / v_contador, 2);
    if v_tip_implementacion not in (2, 3) and p_val_tan < v_val_tas_pactada then
      p_val_tan := v_val_tas_pactada;
    end if;
    If v_tip_interes = 'A' then
      -- Si es un descuento obtiene el tae con el promedio de días.
      p_val_tae := round(pas_bcp.fu_obt_tae(p_val_tan,
                                (v_tot_dias / v_contador)),
                   2);
    Else
      -- Si los días no son fijos o es flexible debe halla por promedio.
      p_val_tae := round(v_acum_tae / v_contador, 2);
    End if;
  END;
  /* Recupera minima cuota vencida de la operacion */
  FUNCTION FU_OBT_MIN_CUO_VENCIDA(P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE,
                        P_FECHA      IN PR_CUOTAS.FEC_VENCIMIENTO%TYPE)
    RETURN NUMBER IS
    v_min_cuota pr_cuotas.nro_cuota%type;
  BEGIN
    select min(nro_cuota)
      into v_min_cuota
      from md_doc_detalles
     where nro_cuenta = p_nro_cuenta
      and (nvl(sal_capital, 0) <> 0 or nvl(sal_interes, 0) <> 0) -- Cuotas con saldo
      and nro_cuota > 0;
    return v_min_cuota;
  END;
  /* Calcula el interes. */
  FUNCTION FU_CAL_INTERES
   (P_FEC_INICIO IN MD_CTA_DOCUMENTOS.FEC_INICIO%TYPE
   ,P_FEC_VENCIMIENTO IN MD_CTA_DOCUMENTOS.FEC_VENCIMIENTO%TYPE
   ,P_MTO_CAPITAL IN MD_CTA_DOCUMENTOS.MONTO%TYPE
   ,P_VAL_TASA IN PR_CTA_PRESTAMOS.VAL_TASA%TYPE
   ,P_DIVISOR IN MD_CTA_DOCUMENTOS.DIA_ANO%TYPE
   )
  RETURN NUMBER
  IS

  V_INTERES MD_CTA_DOCUMENTOS.SAL_INTERES%TYPE;
  V_VAL_TASA MD_CTA_DOCUMENTOS.VAL_TASA%TYPE;
  V_DIA_PLAZO MD_DOC_DETALLES.PLAZO%TYPE;
  BEGIN
    v_val_tasa := p_val_tasa;
    v_dia_plazo   := trunc(p_fec_vencimiento) - trunc(p_fec_inicio) + 1;
    v_interes := v_dia_plazo * p_mto_capital * v_val_tasa/P_DIVISOR;
    RETURN v_interes;
  END;

  /* Recupera MAXIMA cuota vencida de la operacion A LA FECHA*/
  FUNCTION FU_OBT_MAX_CUO_VENCIDA(P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE,
                        P_FECHA      IN PR_CUOTAS.FEC_VENCIMIENTO%TYPE)
    RETURN NUMBER IS
    v_max_cuota pr_cuotas.nro_cuota%type;
  BEGIN
    select max(nro_cuota)
      into v_max_cuota
      from md_doc_detalles
     where nro_cuenta = p_nro_cuenta
      and (nvl(sal_capital, 0) <> 0 or nvl(sal_interes, 0) <> 0) -- Cuotas con saldo
      and nro_cuota > 0
      and fec_vencimiento <= p_fecha;
    return v_max_cuota;
  END;
  /* Devuelve si una operacion es activa o pasiva */
  FUNCTION FU_OBT_TIP_OPERACION(p_nro_cuenta in varchar2) return varchar2 is
    v_tipo varchar2(1);
  BEGIN
    select tipo
      into v_tipo
      from ge_modalidades x, ge_cuentas a
     where a.nro_cuenta = p_nro_cuenta
      and x.cod_modulo = a.cod_modulo
      and x.cod_modalidad = a.cod_modalidad;
    return v_tipo;
  exception
    when others then
      return null;
  END;

  /* pago de operaciones pasivas */
  PROCEDURE PR_PAG_OPERACION(p_nro_cuenta         in varchar2,
                    p_NRO_CUO_DESDE      in number,
                    p_NRO_CUO_HASTA      in number,
                    p_MTO_A_PAGAR        in number,
                    p_MTO_CAPITAL        in number,
                    p_MTO_INTERES        in number,
                    p_MTO_INT_DESCONTADO in number,
                    p_MTO_INT_MORATORIO  IN NUMBER,
                    P_MTO_IMPUESTO       IN NUMBER,
                    P_MTO_CARGO          IN NUMBER,
                    P_MTO_GARANTIA       IN NUMBER,
                    p_cod_ofi_origen     in number,
                    p_fecha              in date,
                    p_hora               in varchar2,
                    p_nro_secuencia      in out number) IS

    --- Variables de tipo de registro
    r_pcta  md_cta_documentos%rowtype;
    r_gmovi ge_movimientos%rowtype;
    --- Variables para movimientos
    v_nro_secuencia ge_movimientos.nro_secuencia%type;
    v_hora          ge_movimientos.hora%type;
    v_cod_usuario   ge_movimientos.cod_usuario%type;
    --v_mto_interes        md_cta_documentos.mto_interes%type;
    v_error         number(05);
    v_mensaje       varchar2(1000);
    v_cotizacion    ge_cotizaciones.val_conversion%type;
    v_capital       md_cta_documentos.monto%type;
    v_cod_mon_local ba_monedas.cod_moneda%type;
    ---
    v_cod_tra_cargo      number := 704; ----------------- Transaccion por cargo
    v_tot_cargo          number := 0; ------------------- Monto del cargo + impuesto
    v_cod_tas_cargo      number;
    v_val_tas_cargo      number;
    v_val_cargo          number;
    v_cod_tra_impuesto   number;
    v_cod_tas_impuesto   number;
    v_val_tas_impuesto   number;
    v_val_impuesto       number;
    v_tip_cancelacion    varchar2(1) := 'P';
    v_tot_capital        number := 0;
    v_tot_interes        number := 0;
    v_tot_int_descontado number := 0;
    v_cap_amortizado     number := 0;
    v_int_amortizado     number := 0;
    v_estado             varchar2(1);
    v_int_descontado     number := 0;
    cursor cuotas is
      select *
        from md_doc_detalles
       where nro_cuenta = p_nro_cuenta
        and nro_cuota between p_nro_cuo_desde and p_nro_cuo_hasta
        and estado <> 'N'
       order by nro_cuota;
    cursor garantias is
      select a.nro_cuenta,
           a.nro_garantia,
           a.cod_garantia,
           nvl(a.cod_moneda, r_pcta.cod_moneda) cod_moneda,
           nvl(p_mto_garantia, 0) monto,
           a.observacion,
           b.cod_transaccion2
        from pr_gar_tipos b, md_garantias a
       where a.nro_cuenta = p_nro_cuenta
        and b.cod_garantia = a.cod_garantia
        and b.cod_transaccion2 is not null
        and rownum = 1; -- ahora se desplica por el monto que dice en pantalla

  BEGIN
    --- Cargar variables
    v_nro_secuencia := p_nro_secuencia;
    v_hora          := p_hora;
    --- Recuperar datos de la Operación
    pr_obt_datos(p_nro_cuenta, r_pcta);
    if v_error <> 0 then
      raise_application_error(-20000,
                      v_mensaje || ' ' || 'error:' || v_error);
    end if;
    --- Verificar monto de desembolso
    if p_mto_a_pagar <>
      nvl(p_mto_capital, 0) + nvl(p_mto_interes, 0) + nvl(p_mto_cargo, 0) +
      nvl(p_mto_impuesto, 0) + nvl(p_mto_int_moratorio, 0) then
      raise_application_error(-20000,
                      'Monto a Pagar no coincide con Capital + Interés pagado + Cargos e Impuestos');
    end if;
    --- Inicializar variables de movimientos
    v_cod_usuario := user;
    --- busco el valor de la cotizacion
    v_cod_mon_local := pag_gen.fu_obt_mon_local;
    v_cotizacion    := null;
    if r_pcta.cod_moneda <> v_cod_mon_local then
      --- Actualizar cargos a la cotizacion del dia.
      v_cotizacion := pag_gen.fu_obt_cotizacion(r_pcta.cod_moneda, p_fecha);
    end if;
    v_capital := nvl(p_mto_capital, 0);

    if nvl(r_pcta.sal_capital, 0) + nvl(r_pcta.sal_interes, 0) -
      nvl(p_mto_int_descontado, 0) <= nvl(p_mto_a_pagar, 0) then
      v_tip_cancelacion := 'T';
    end if;
    --- Generar movimiento de por el cambio de estado
    if v_tip_cancelacion = 'T' then
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := p_fecha;
      r_gmovi.cod_modulo      := r_pcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
      r_gmovi.cod_oficina     := r_pcta.cod_oficina;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.cod_moneda      := r_pcta.cod_moneda;
      r_gmovi.est_cuenta      := 'N';
      r_gmovi.cod_tra_padre   := 360;
      r_gmovi.cod_transaccion := 401;
      r_gmovi.fec_valor       := p_fecha;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.concepto        := 'Cambio de Estado por Cancel.';
      r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
      r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
      r_gmovi.nro_documento   := r_pcta.nro_cuenta;
      r_gmovi.nro_documento3   := nvl(p_nro_cuo_desde,0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);

      --- actualizo el estado -----------------------
      update md_cta_documentos
        set estado = 'N', fec_cancelacion = p_fecha
       where nro_cuenta = p_nro_cuenta;

    end if;

    if nvl(P_MTO_GARANTIA, 0) > 0 then
      -- se genera movimientos por la garantias
      for ga in garantias loop
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := p_fecha;
        r_gmovi.cod_modulo      := r_pcta.cod_modulo;
        r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
        r_gmovi.cod_oficina     := r_pcta.cod_oficina;
        r_gmovi.nro_cuenta      := p_nro_cuenta;
        r_gmovi.cod_moneda      := ga.cod_moneda;
        r_gmovi.est_cuenta      := null;
        r_gmovi.cod_tra_padre   := 360;
        r_gmovi.cod_transaccion := ga.cod_transaccion2;
        r_gmovi.monto           := ga.monto;
        r_gmovi.fec_valor       := p_fecha;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
        r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
        r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
        r_gmovi.nro_documento   := r_pcta.nro_cuenta;
        r_gmovi.concepto        := 'Garantia ' || ga.nro_garantia;
        r_gmovi.nro_documento3   := nvl(p_nro_cuo_desde,0);
        --r_gmovi.cotizacion         := v_cotizacion;
        --r_gmovi.mto_equ_local      := round(trunc(v_capital,2)*v_cotizacion,0);
        pag_gen.pr_ins_ge_movimiento(r_gmovi);

      end loop;

    end if;

    -- genero el movimiento por el capital pagado
    if p_mto_capital > 0 then
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := p_fecha;
      r_gmovi.cod_modulo      := r_pcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
      r_gmovi.cod_oficina     := r_pcta.cod_oficina;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.cod_moneda      := r_pcta.cod_moneda;
      r_gmovi.est_cuenta      := null;
      r_gmovi.cod_tra_padre   := 360;
      r_gmovi.cod_transaccion := 711;
      r_gmovi.monto           := p_mto_capital;
      r_gmovi.fec_valor       := p_fecha;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
      r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
      r_gmovi.nro_documento   := r_pcta.nro_cuenta;
      r_gmovi.concepto        := 'Pago de Cap. ' || p_nro_cuenta;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(trunc(v_capital, 2) * v_cotizacion, 0);
      r_gmovi.nro_documento3   := nvl(p_nro_cuo_desde,0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);

      --- actualizo fecha de ultimo pago -----------------------
      update md_cta_documentos
        set fec_ult_pago = p_fecha
       where nro_cuenta = p_nro_cuenta;

    end if;

    --- genero los movimientos por el interes pagado
    if p_mto_interes > 0 then
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := p_fecha;
      r_gmovi.cod_modulo      := r_pcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
      r_gmovi.cod_oficina     := r_pcta.cod_oficina;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.cod_moneda      := r_pcta.cod_moneda;
      r_gmovi.cod_tra_padre   := 360;
      r_gmovi.cod_transaccion := 719;
      r_gmovi.concepto        := 'Pago de Int. ' || p_nro_cuenta;
      r_gmovi.monto           := nvl(p_mto_interes, 0);
      r_gmovi.fec_valor       := p_fecha;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
      r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
      r_gmovi.nro_documento   := r_pcta.nro_cuenta;
      r_gmovi.cotizacion      := v_cotizacion;
      --r_gmovi.mto_equ_local      := round(trunc(nvl(r_pcta.mto_interes,0),2)*v_cotizacion,0);
      r_gmovi.mto_equ_local := round(trunc(nvl(p_mto_interes, 0), 2) *
                           v_cotizacion,
                           0);
      r_gmovi.nro_documento3   := nvl(p_nro_cuo_desde,0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;
    IF p_mto_impuesto > 0 THEN
      -- impuesto
      v_nro_secuencia       := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.concepto      := 'IVA s/ Interes';
      --r_gmovi.cod_transaccion    := 518; -- impuesto
      r_gmovi.cod_transaccion := 414; -- impuesto
      r_gmovi.cod_tasa        := 420;
      r_gmovi.val_tasa        := 5;
      r_gmovi.monto           := p_mto_impuesto;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      r_gmovi.nro_documento3   := nvl(p_nro_cuo_desde,0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END IF;
    if p_mto_int_descontado > 0 then
      --- genero los movimientos por el interes descontado
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := p_fecha;
      r_gmovi.cod_modulo      := r_pcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
      r_gmovi.cod_oficina     := r_pcta.cod_oficina;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.cod_moneda      := r_pcta.cod_moneda;
      r_gmovi.cod_tra_padre   := 360;
      r_gmovi.cod_transaccion := 803;
      r_gmovi.concepto        := 'Int. Descontado ' || p_nro_cuenta;
      r_gmovi.monto           := nvl(p_mto_int_descontado, 0);
      r_gmovi.fec_valor       := p_fecha;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
      r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
      r_gmovi.nro_documento   := r_pcta.nro_cuenta;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;
      r_gmovi.mto_equ_local   := round(trunc(nvl(r_pcta.mto_interes, 0), 2) *
                            v_cotizacion,
                            0);
      r_gmovi.nro_documento3   := nvl(p_nro_cuo_desde,0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;

    ---
    prg_obt_cargos(p_cod_ofi_origen,
              p_nro_cuenta,
              r_pcta.cod_moneda,
              p_mto_cargo,
              r_pcta.cod_modulo,
              r_pcta.cod_modalidad,
              v_cod_tra_cargo,
              v_cod_tas_cargo,
              v_val_tas_cargo,
              v_val_cargo,
              v_cod_tra_impuesto,
              v_cod_tas_impuesto,
              v_val_tas_impuesto,
              v_val_impuesto);
    if v_val_cargo > 0 then
      -- existe cargo, se genera movimiento
      v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
      r_gmovi.cod_usuario   := v_cod_usuario;
      r_gmovi.hora          := v_hora;
      r_gmovi.fecha         := p_fecha;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      --
      r_gmovi.cod_modulo      := r_pcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
      r_gmovi.cod_oficina     := r_pcta.cod_oficina;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.cod_moneda      := r_pcta.cod_moneda;
      r_gmovi.fec_valor       := p_fecha;
      r_gmovi.cod_tra_padre   := 360;
      r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
      r_gmovi.cod_transaccion := v_cod_tra_cargo;
      r_gmovi.monto           := v_val_cargo;
      r_gmovi.nro_documento   := null;
      r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Comision por la Compra';
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_tasa        := v_cod_tas_cargo;
      r_gmovi.val_tasa        := v_val_tas_cargo;
      r_gmovi.cod_rubro       := null;
      r_gmovi.nro_caja        := null;
      r_gmovi.nro_documento3   := nvl(p_nro_cuo_desde,0);
      -- inserto el registro de movimientos
      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
    end if;
    if v_val_impuesto > 0 then
      -- existe impuesto, se genera movimiento
      v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
      r_gmovi.cod_usuario   := v_cod_usuario;
      r_gmovi.hora          := v_hora;
      r_gmovi.fecha         := p_fecha;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      --
      r_gmovi.cod_modulo      := r_pcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
      r_gmovi.cod_oficina     := r_pcta.cod_oficina;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.cod_moneda      := r_pcta.cod_moneda;
      r_gmovi.fec_valor       := p_fecha;
      r_gmovi.cod_tra_padre   := 360;
      r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
      r_gmovi.cod_transaccion := v_cod_tra_impuesto;
      r_gmovi.monto           := v_val_impuesto;
      r_gmovi.nro_documento   := null;
      r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'IVA s/ Comision';
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_tasa        := v_cod_tas_impuesto;
      r_gmovi.val_tasa        := v_val_tas_impuesto;
      r_gmovi.cod_rubro       := null;
      r_gmovi.nro_caja        := null;
      r_gmovi.nro_documento3   := nvl(p_nro_cuo_desde,0);
      -- inserto el registro de movimientos
      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
    end if;

    IF p_mto_int_moratorio > 0 THEN
      -- interes moratorio
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.cod_transaccion := 806; -- interes moratorio
      r_gmovi.concepto        := 'Interes moratorio';
      r_gmovi.monto           := p_mto_int_moratorio;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      r_gmovi.nro_documento3   := nvl(p_nro_cuo_desde,0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END IF;

    --- cargos
    /*
      prg_obt_cargos(p_cod_ofi_origen,p_nro_cuenta,r_pcta.cod_moneda,r_pcta.comision,
                     r_pcta.cod_modulo,r_pcta.cod_modalidad,v_cod_tra_cargo,v_cod_tas_cargo,v_val_tas_cargo,v_val_cargo,
                     v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);
      if v_val_cargo > 0 then
         -- existe cargo, se genera movimiento
         v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := p_fecha;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.cod_modulo      := r_pcta.cod_modulo;
         r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
         r_gmovi.cod_oficina     := r_pcta.cod_oficina;
         r_gmovi.nro_cuenta      := p_nro_cuenta;
         r_gmovi.cod_moneda      := r_pcta.cod_moneda;
         r_gmovi.fec_valor       := p_fecha;
         r_gmovi.cod_tra_padre   := v_cod_tra_cargo;
         r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
         r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
         r_gmovi.cod_transaccion := v_cod_tra_cargo;
         r_gmovi.monto           := v_val_cargo;
         r_gmovi.nro_documento   := null;
         r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := 'Comision por la Compra';
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_tasa        := v_cod_tas_cargo;
         r_gmovi.val_tasa        := v_val_tas_cargo;
         r_gmovi.cod_rubro       := null;
         r_gmovi.nro_caja        := null;
         -- inserto el registro de movimientos
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
      end if;
      if v_val_impuesto > 0 then
         -- existe impuesto, se genera movimiento
         v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := p_fecha;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.cod_modulo      := r_pcta.cod_modulo;
         r_gmovi.cod_modalidad   := r_pcta.cod_modalidad;
         r_gmovi.cod_oficina     := r_pcta.cod_oficina;
         r_gmovi.nro_cuenta      := p_nro_cuenta;
         r_gmovi.cod_moneda      := r_pcta.cod_moneda;
         r_gmovi.fec_valor       := p_fecha;
         r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
         r_gmovi.cod_mod_padre   := r_pcta.cod_modulo;
         r_gmovi.cod_mad_padre   := r_pcta.cod_modalidad;
         r_gmovi.cod_transaccion := v_cod_tra_impuesto;
         r_gmovi.monto           := v_val_impuesto;
         r_gmovi.nro_documento   := null;
         r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := 'IVA s/ Comision';
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_tasa        := v_cod_tas_impuesto;
         r_gmovi.val_tasa        := v_val_tas_impuesto;
         r_gmovi.cod_rubro       := null;
         r_gmovi.nro_caja        := null;
         -- inserto el registro de movimientos
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
      end if;
      */
    v_tot_capital        := p_mto_capital;
    v_tot_interes        := p_mto_interes;
    v_tot_int_descontado := p_mto_int_descontado;
    for ct in cuotas loop
      -- capital de la cuota
      if v_tot_capital > ct.sal_capital then
        v_cap_amortizado := ct.sal_capital;
      else
        v_cap_amortizado := v_tot_capital;
      end if;
      v_tot_capital := nvl(v_tot_capital, 0) - v_cap_amortizado;
      -- interes amortizado de la cuota
      if v_tot_interes > ct.sal_interes then
        v_int_amortizado := ct.sal_interes;
      else
        v_int_amortizado := v_tot_interes;
        -- ya se cobro todo el interes, puede que el resto sea descontado
        if v_tot_int_descontado > (ct.sal_interes - v_int_amortizado) then
          v_int_descontado := (ct.sal_interes - v_int_amortizado);
        else
          v_int_descontado := v_tot_int_descontado;
        end if;
        v_tot_int_descontado := nvl(v_tot_int_descontado, 0) -
                        v_int_descontado;
      end if;
      v_tot_interes := nvl(v_tot_interes, 0) - v_int_amortizado;
      -- ya tengo los datos por cuota
      if nvl(v_cap_amortizado, 0) + nvl(v_int_amortizado, 0) +
        nvl(v_int_descontado, 0) >=
        nvl(ct.sal_capital, 0) + nvl(ct.sal_interes, 0) then
        -- cambio de estado
        v_estado := 'N';
      else
        v_estado := ct.estado;
      end if;
      -- actualizo los datos
      update md_doc_detalles
        set estado             = v_estado,
           sal_capital        = nvl(sal_capital, 0) -
                         nvl(v_cap_amortizado, 0),
           sal_interes        = nvl(sal_interes, 0) -
                         (nvl(v_int_amortizado, 0) +
                          nvl(v_int_descontado, 0)),
           mto_int_descontado = nvl(mto_int_descontado, 0) +
                         nvl(v_int_descontado, 0),
           fec_ult_pago       = p_fecha
       where nro_cuenta = ct.nro_cuenta
        and nro_cuota = ct.nro_cuota;
      ---  inserto en md_cobros

    end loop;

    -- actualizo los saldos
    update md_cta_documentos
      set sal_capital        = nvl(sal_capital, 0) - nvl(p_mto_capital, 0),
         sal_interes        = nvl(sal_interes, 0) -
                       (nvl(p_mto_interes, 0) +
                        nvl(p_mto_int_descontado, 0)),
         tot_int_descontado = nvl(tot_int_descontado, 0) +
                       nvl(p_mto_int_descontado, 0),
         val_int_devengar   = val_int_devengar - p_mto_int_descontado
     where nro_cuenta = p_nro_cuenta;

    --- Cargar variables de retorno
    p_nro_secuencia := v_nro_secuencia;

  END;

  --Realiza la confirmacion de prestamos y call money recibido
  PROCEDURE PR_CON_OPERACION(P_NRO_CUENTA     IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
                    P_COD_OFI_ORIGEN IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE,
                    P_CONCEPTO       IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
                    P_FECHA          IN GE_MOVIMIENTOS.FECHA%TYPE,
                    P_HORA           IN OUT GE_MOVIMIENTOS.HORA%TYPE,
                    P_NRO_SECUENCIA  IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%Type,
                    P_COD_TRA_PADRE  IN NUMBER default 999,
                    P_COD_MOD_PADRE  IN NUMBER,
                    P_COD_MAD_PADRE  IN Number) IS

    --- Datos del registros de cuentas
    r_docu        md_cta_documentos%rowtype;
    r_gmovi       ge_movimientos%rowtype;
    v_sal_cobrado pr_cuotas.sal_capital%type;
    v_sal_capital pr_cuotas.sal_capital%type;
    v_tot_pag_cap pr_cta_prestamos.sal_capital%type;
    v_pre_sal_cap pr_cta_prestamos.sal_capital%type;
    v_resultado   md_cta_documentos.monto%Type;
    v_dia_interes number;
    v_redondeo    number;
    --- Variables de movimientos
    v_fecha         ge_movimientos.fecha%type;
    v_fec_actual    ge_movimientos.fecha%type;
    v_nro_secuencia ge_movimientos.nro_secuencia%type;
    v_hora          ge_movimientos.hora%type;
    v_cotizacion    ge_movimientos.cotizacion%type;
    --
    v_cod_tra_cargo    number := 704; ----------------- Transaccion por cargo
    v_tot_cargo        number := 0; ------------------- Monto del cargo + impuesto
    v_cod_tas_cargo    number;
    v_val_tas_cargo    number;
    v_val_cargo        number;
    v_cod_tra_impuesto number;
    v_cod_tas_impuesto number;
    v_val_tas_impuesto number;
    v_val_impuesto     number;

    cursor garantias is
      select a.nro_cuenta,
           a.nro_garantia,
           a.cod_garantia,
           a.cod_moneda,
           a.monto,
           a.observacion,
           b.cod_transaccion1
        from pr_gar_tipos b, md_garantias a
       where a.nro_cuenta = p_nro_cuenta
        and b.cod_garantia = a.cod_garantia
        and b.cod_transaccion1 is not null;

  BEGIN
    --- Recuperar datos del documento
    pam_doc.pr_obt_datos(p_nro_cuenta, r_docu);

    --- Inicializar datos del movimiento
    v_fecha      := p_fecha;
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(10);

    v_hora          := nvl(p_hora, to_char(sysdate, 'HH24:MI:SS'));
    v_nro_secuencia := nvl(p_nro_secuencia, 0);

    If r_docu.cod_moneda <> pag_gen.fu_obt_mon_local then
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                             10,
                             r_docu.cod_modalidad,
                             r_docu.cod_moneda);
    else
      v_redondeo := 0;
    End if;

    --- Actualizar maestro de documentos
    update md_cta_documentos
      set estado           = 'C',
         fec_cam_estado   = p_fecha,
         val_int_devengar = mto_interes,
         sal_capital      = monto,
         sal_interes      = decode(r_docu.tip_cob_interes,
                          'D',
                          0,
                          mto_interes)
     where nro_cuenta = p_nro_cuenta;
    -- Cambio el estado de las cuotas
    update md_doc_detalles
      set estado      = 'C',
         sal_interes = decode(r_docu.tip_cob_interes, 'D', 0, sal_interes)
     where nro_cuenta = p_nro_cuenta;

    --- GENERAR MOVIMIENTOS
    r_gmovi.cod_usuario    := User;
    r_gmovi.hora           := v_hora;
    r_gmovi.fecha          := PAG_CAL.FU_OBT_FEC_ACTUAL(10);
    r_gmovi.cod_modulo     := r_docu.cod_modulo;
    r_gmovi.cod_modalidad  := r_docu.cod_modalidad;
    r_gmovi.cod_oficina    := r_docu.cod_oficina;
    r_gmovi.nro_cuenta     := p_nro_cuenta;
    r_gmovi.cod_moneda     := r_docu.cod_moneda;
    r_gmovi.est_cuenta     := null;
    r_gmovi.cod_tra_padre  := p_cod_tra_padre;
    r_gmovi.cod_mod_padre  := p_cod_mod_padre;
    r_gmovi.cod_mad_padre  := p_cod_mad_padre;
    r_gmovi.fec_valor      := p_fecha;
    r_gmovi.reversado      := 'N';
    r_gmovi.protegido      := 'N';
    r_gmovi.estado         := 'N';
    r_gmovi.cod_ofi_origen := p_cod_ofi_origen;
    r_gmovi.nro_documento  := p_nro_cuenta;
    r_gmovi.referencia     := r_docu.nro_documento;
    r_gmovi.concepto       := nvl(p_concepto, 'Confirmacion de Oper.');
    v_cotizacion           := null;

    IF r_docu.monto > 0 THEN
      -- por el interes
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.cod_transaccion := 801; -- Afecta Capital
      r_gmovi.monto           := r_docu.sal_val_presente;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END IF;
    ---se generan datos de cobro de intereses
    If r_docu.mto_interes > 0 then
      --- Interes a Devengar
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.cod_transaccion := 802; -- No afecta
      r_gmovi.monto           := r_docu.mto_interes;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;
    ---se generan datos por el interes pagado por adelantado
    If r_docu.mto_interes > 0 and r_docu.tip_cob_interes = 'D' then
      --- Interes pagad
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.emi_aviso       := 'S';
      r_gmovi.cod_transaccion := 719; -- No afecta
      r_gmovi.monto           := r_docu.mto_interes;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;
    If nvl(r_docu.mto_impuesto, 0) > 0 then
      --- Impuesto sobre el interés, call money es el único que tiene
      v_nro_secuencia       := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      r_gmovi.emi_aviso     := 'S';
      --r_gmovi.cod_transaccion     := 518; -- Iva sobre interés
      /*a pedido de Forcado la transaccion de iva no puede ser la 518*/
      r_gmovi.cod_transaccion := 414; -- Iva sobre interés JCLG
      r_gmovi.monto           := nvl(r_docu.mto_impuesto, 0);
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion, 0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;
    /*
      If nvl(r_docu.monto,0) - nvl(r_docu.mto_interes,0) > 0 then --- Valor del capital
        -- inserta monto - interes
        v_nro_secuencia             := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia       := v_nro_secuencia;
        r_gmovi.emi_aviso           := 'S';
        r_gmovi.cod_transaccion     := 805; -- No afecta
        r_gmovi.monto               := nvl(r_docu.monto,0) - nvl(r_docu.mto_interes,0);
        r_gmovi.cotizacion          := v_cotizacion;
        r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,0);
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;
      */
    --- Generar movimiento del cambio de estado a vigente, confirmado

    v_nro_secuencia             := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia       := v_nro_secuencia;
    r_gmovi.emi_aviso           := 'N';
    r_gmovi.cod_transaccion     := 425;
    r_gmovi.est_cuenta          := 'C';
    r_gmovi.monto               := null;
    r_gmovi.cotizacion          := null;
    r_gmovi.mto_equ_local       := null;
    r_gmovi.cod_usu_autorizador := null;
    r_gmovi.cod_autorizacion    := null;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
    -- CARGOS
    if r_docu.comision > 0 then
      prg_obt_cargos(p_cod_ofi_origen,
                r_docu.nro_cuenta,
                r_docu.cod_moneda,
                r_docu.comision,
                r_docu.cod_modulo,
                r_docu.cod_modalidad,
                v_cod_tra_cargo,
                v_cod_tas_cargo,
                v_val_tas_cargo,
                v_val_cargo,
                v_cod_tra_impuesto,
                v_cod_tas_impuesto,
                v_val_tas_impuesto,
                v_val_impuesto);
      if v_val_cargo > 0 then
        -- existe cargo, se genera movimiento
        v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        --
        r_gmovi.cod_moneda      := r_docu.cod_moneda;
        r_gmovi.cod_transaccion := v_cod_tra_cargo;
        r_gmovi.monto           := v_val_cargo;
        r_gmovi.nro_documento   := null;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'Cargo en Desembolso';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.est_cuenta      := null;
        r_gmovi.cod_tasa        := v_cod_tas_cargo;
        r_gmovi.val_tasa        := v_val_tas_cargo;
        r_gmovi.cod_rubro       := null;
        r_gmovi.nro_caja        := null;
        -- inserto el registro de movimientos
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
      end if;
      if v_val_impuesto > 0 then
        -- existe impuesto, se genera movimiento
        v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        --
        r_gmovi.cod_transaccion := v_cod_tra_impuesto;
        r_gmovi.monto           := v_val_impuesto;
        r_gmovi.nro_documento   := null;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'IVA s/ cargo';
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_tasa        := v_cod_tas_impuesto;
        r_gmovi.val_tasa        := v_val_tas_impuesto;
        r_gmovi.cod_rubro       := null;
        r_gmovi.nro_caja        := null;
        -- inserto el registro de movimientos
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
      end if;
    end if;

    -- se genera movimientos por la garantias
    for ga in garantias loop
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_moneda      := ga.cod_moneda;
      r_gmovi.est_cuenta      := null;
      r_gmovi.cod_transaccion := ga.cod_transaccion1;
      r_gmovi.monto           := ga.monto;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.concepto        := 'Garantia ' || ga.nro_garantia;
      --r_gmovi.cotizacion         := v_cotizacion;
      --r_gmovi.mto_equ_local      := round(trunc(v_capital,2)*v_cotizacion,0);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);

    end loop;
    p_nro_secuencia := v_nro_secuencia;
  END;
  -- cambio de tasa
  PROCEDURE PR_CAM_TASA(p_nro_cuenta   VARCHAR2,
                 p_val_tasa_nva NUMBER,
                 p_fec_vigencia in date) IS
    --- Variables auxiliares
    v_vez           number(01) := 0;
    v_contador      number(01) := 0;
    v_redondeo      number(2);
    v_sal_cap_cuota md_doc_detalles.sal_capital%type;
    v_fec_inicio    md_cta_documentos.fec_inicio%type;
    v_interes       md_doc_detalles.mto_interes%type;
    v_interes1      md_doc_detalles.mto_interes%type;
    v_devengado     md_devengados.mto_dev_actual%type;
    v_devengado1    md_devengados.mto_dev_actual%type;
    v_dif_devengado md_devengados.mto_dev_actual%type :=0;
    v_tot_dif_int   md_doc_detalles.mto_interes%type;
    v_diferencia    md_doc_detalles.mto_interes%type;
    v_cod_modulo    md_cta_documentos.cod_modulo%type;
    v_cod_modalidad md_cta_documentos.cod_modalidad%type;
    v_cod_moneda    md_cta_documentos.cod_moneda%type;
    v_cod_oficina   md_cta_documentos.cod_oficina%type;
    r_gmovi         ge_movimientos%rowtype;
    v_fec_actual    date := pag_cal.fu_obt_fec_actual(10);
    v_vcto          date;
    v_fec_vigencia  date;
    v_fec_ini_dev   date;

    v_impuesto      md_doc_detalles.mto_impuesto%type;
    v_impuesto1     md_doc_detalles.mto_impuesto%type;
    v_dif_impuesto  md_doc_detalles.mto_impuesto%type;
    v_tot_dif_imp   md_doc_detalles.mto_impuesto%type;
    v_val_tasa      md_cta_documentos.val_tasa%type;
    v_divisor       md_cta_documentos.dia_ano%type;

    --- Cursor de cuotas de prestamos restantes a remodificar
    cursor c_cuotas is
    select nro_cuota,
    o.mto_capital,
    o.mto_interes,
    o.sal_capital,
    o.sal_interes,
    p.sal_capital sal_cap_pre,
    p.sal_interes sal_int_pre,
    o.fec_vencimiento,
    p.cod_modalidad,
    p.cod_oficina,
    p.cod_moneda,
    o.plazo,
    o.mto_impuesto,
    p.val_tasa,
    p.dia_ano
    from md_doc_detalles o, md_cta_documentos p
    where o.nro_cuenta = p_nro_cuenta
    and p.nro_cuenta = O.nro_cuenta
    and o.sal_interes <> 0
    --and o.estado != 'N'
    --and p.estado = 'C'--vigente
    --and to_char(o.fec_vencimiento,'yyyy') >= to_char(v_fec_actual,'yyyy')--año actual
      and o.fec_vencimiento >= p_fec_vigencia
    order by o.nro_cuota;

    --- Cuotas con devengados modificados
    cursor c_cuo_devengados is
    select nro_cuota,
    o.mto_capital,
    o.mto_interes,
    o.sal_capital,
    o.sal_interes,
    p.sal_capital sal_cap_pre,
    p.sal_interes sal_int_pre,
    o.fec_vencimiento,
    p.cod_modalidad,
    p.cod_oficina,
    p.cod_moneda,
    o.plazo,
    o.mto_impuesto,
    p.val_tasa,
    p.dia_ano
    from md_doc_detalles o, md_cta_documentos p
    where o.nro_cuenta = p_nro_cuenta
    and p.nro_cuenta = O.nro_cuenta
    and o.sal_interes <> 0
    --and o.estado != 'N'
    --and p.estado = 'C'--vigente
    --and to_char(o.fec_vencimiento,'yyyy') >= to_char(v_fec_actual,'yyyy')--año actual
    and o.fec_vencimiento >= p_fec_vigencia
    and o.fec_vencimiento < v_fec_actual
    order by o.nro_cuota;

  BEGIN

    begin
      select cod_modulo, cod_modalidad, cod_moneda, cod_oficina
        into v_cod_modulo, v_cod_modalidad, v_cod_moneda,v_cod_oficina
        from md_cta_documentos
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
      raise_application_error(-20000, 'Obtener datos MD_CTA_DOCUMENTOS');
    end;

    -- Fecha de Vigencia --------------------
    if v_cod_modalidad = 117 then
       v_fec_vigencia := p_fec_vigencia - 1;
    else
       v_fec_vigencia := p_fec_vigencia;
    end if;
    -----------------------------------------

    if v_cod_moneda = pag_gen.fu_obt_mon_local then
      v_redondeo := 0;
    else
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda,v_cod_oficina);
    end if;
    v_tot_dif_int := 0;
    v_tot_dif_imp := 0;

      v_contador:=0;
    for dev in c_cuo_devengados loop
      if v_vez = 0 then
        v_contador:=1;
        v_vez           := 1;
        v_sal_cap_cuota := nvl(dev.sal_cap_pre, 0);
        v_val_tasa := dev.val_tasa;

        --Calcular devengado por la tasa anterior
        v_devengado       := round(pam_doc.fu_cal_interes(p_fec_vigencia,dev.fec_vencimiento-1,v_sal_cap_cuota,dev.val_tasa,dev.dia_ano*100), v_redondeo);
        --Calcular devengado por la tasa nueva
        v_devengado1       := round(pam_doc.fu_cal_interes(p_fec_vigencia,dev.fec_vencimiento-1,v_sal_cap_cuota,p_val_tasa_nva,dev.dia_ano*100), v_redondeo);
      else
        v_fec_inicio    := dev.fec_vencimiento - dev.plazo;
        --Calcular devengado por la tasa anterior
        v_devengado       := round(pam_doc.fu_cal_interes(v_fec_inicio,dev.fec_vencimiento-1,v_sal_cap_cuota,dev.val_tasa,dev.dia_ano*100), v_redondeo);
        --Calcular devengado por la tasa nueva
          v_devengado1       := round(pam_doc.fu_cal_interes(v_fec_inicio,dev.fec_vencimiento-1,v_sal_cap_cuota,p_val_tasa_nva,dev.dia_ano*100), v_redondeo);

      end if;
      v_dif_devengado := v_dif_devengado+(nvl(v_devengado1,0)-nvl(v_devengado,0));
      v_sal_cap_cuota := v_sal_cap_cuota - nvl(dev.sal_capital, 0);
      v_vcto          := dev.fec_vencimiento-1;
      v_divisor       := dev.dia_ano;
    end loop;

    if v_vcto < v_fec_actual then --falta devengar hasta la fecha del cambio de tasa
       --Calcular devengado por la tasa anterior
       v_devengado       := round(pam_doc.fu_cal_interes(v_vcto,v_fec_actual-1,v_sal_cap_cuota,v_val_tasa,v_divisor*100), v_redondeo);
       --Calcular devengado por la tasa nueva
       v_devengado1       := round(pam_doc.fu_cal_interes(v_vcto,v_fec_actual-1,v_sal_cap_cuota,p_val_tasa_nva,v_divisor*100), v_redondeo);

       v_dif_devengado := v_dif_devengado+(nvl(v_devengado1,0)-nvl(v_devengado,0));
    end if;

    --Si el cursor no trajo cuota
    if v_contador = 0 then
       select sal_capital, val_tasa, dia_ano
         into v_sal_cap_cuota, v_val_tasa, v_divisor
         from md_cta_documentos
        where nro_cuenta = p_nro_cuenta;

        select nvl(max(d.fec_vencimiento), min(c.fec_inicio))
          into v_fec_ini_dev
          from md_doc_detalles d, md_cta_documentos c
         where d.nro_cuenta = c.nro_cuenta
           and d.nro_cuenta = p_nro_cuenta
           and d.estado = 'C';--Estado vigente

        if v_fec_ini_dev < v_fec_vigencia then
          v_fec_ini_dev := v_fec_vigencia;
        end if;
      --Calcular devengado por la tasa anterior
        v_devengado       := round(pam_doc.fu_cal_interes(v_fec_ini_dev,v_fec_actual-1,v_sal_cap_cuota,v_val_tasa,v_divisor*100), v_redondeo);
      --Calcular devengado por la tasa nueva
        v_devengado1      := round(pam_doc.fu_cal_interes(v_fec_ini_dev,v_fec_actual-1,v_sal_cap_cuota,p_val_tasa_nva,v_divisor*100), v_redondeo);

        v_dif_devengado := nvl(v_devengado1,0)-nvl(v_devengado,0);
    end if;

    for cuo in c_cuotas loop
        v_fec_inicio    := cuo.fec_vencimiento - cuo.plazo;
        if v_fec_inicio < p_fec_vigencia and cuo.fec_vencimiento > p_fec_vigencia then
           --- Solo para la primera vez el saldo capital es igual al del prestamo
           v_sal_cap_cuota := nvl(cuo.sal_cap_pre, 0);
           --Calcular porcion del interes por la tasa anterior
           v_interes       := round(pam_doc.fu_cal_interes(v_fec_inicio,v_fec_vigencia-1,v_sal_cap_cuota,cuo.val_tasa,cuo.dia_ano*100), v_redondeo);
           v_impuesto      := round(v_interes*0.05,v_redondeo);
           --Calcular porcion del interes por la tasa nueva
           v_interes1      := ROUND(pam_doc.fu_cal_interes(v_fec_vigencia,cuo.fec_vencimiento-1,v_sal_cap_cuota,p_val_tasa_nva,cuo.dia_ano*100), v_redondeo);
           v_impuesto1     := round(v_interes1*0.05,v_redondeo);

           v_interes       := v_interes+v_interes1;
          v_diferencia    := nvl(v_interes, 0) - nvl(cuo.mto_interes, 0);
           v_impuesto      := v_impuesto+v_impuesto1;
          v_dif_impuesto  := nvl(v_impuesto, 0) - nvl(cuo.mto_impuesto, 0);
        else
           v_fec_inicio    := cuo.fec_vencimiento - cuo.plazo;
           v_interes       := round(pam_doc.fu_cal_interes(v_fec_inicio,cuo.fec_vencimiento-1,v_sal_cap_cuota,p_val_tasa_nva, cuo.dia_ano*100), v_redondeo);
          v_diferencia    := nvl(v_interes, 0) - nvl(cuo.mto_interes, 0);
           v_impuesto      := round(v_interes*0.05,v_redondeo);
          v_dif_impuesto  := nvl(v_impuesto, 0) - nvl(cuo.mto_impuesto, 0);
        end if;
      --- Actualizar cuotas y prestamos
      update md_doc_detalles
          set mto_interes  = nvl(cuo.mto_interes, 0) + v_diferencia,
             sal_interes  = nvl(cuo.sal_interes, 0) + v_diferencia,
             mto_impuesto = nvl(cuo.mto_impuesto, 0) + v_dif_impuesto
       where nro_cuenta   = p_nro_cuenta
         and nro_cuota    = cuo.nro_cuota;
      ---
      v_sal_cap_cuota := v_sal_cap_cuota - nvl(cuo.sal_capital, 0);
        v_tot_dif_int   := v_tot_dif_int + v_diferencia;
        v_tot_dif_imp   := nvl(v_tot_dif_imp,0) + nvl(v_dif_impuesto,0);
    end loop;

    update md_cta_documentos
      set sal_interes = nvl(sal_interes, 0) + v_tot_dif_int,
          mto_interes = nvl(mto_interes, 0) + v_tot_dif_int,
          val_int_devengar = nvl(val_int_devengar, 0) + v_tot_dif_int - v_dif_devengado,
          dev_acumulado = nvl(dev_acumulado, 0) + v_dif_devengado,
           val_tasa    = p_val_tasa_nva
     where nro_cuenta = p_nro_cuenta;

     if nvl(v_tot_dif_int,0) > 0 then
        r_gmovi.cod_transaccion := 802;
    else
        r_gmovi.cod_transaccion := 720;
    end if;
    --- genero los movimientos por el devengamiento y el interes ----
    r_gmovi.nro_secuencia   := 1;
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := to_char(sysdate, 'HH24:MI:SS');
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.cod_modulo      := 10;
    r_gmovi.cod_modalidad   := v_cod_modalidad;
    r_gmovi.cod_oficina     := v_cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.est_cuenta      := null;
    r_gmovi.cod_tra_padre   := 300;
    r_gmovi.concepto        := 'Interes ajustado';
    r_gmovi.monto           := abs(nvl(v_tot_dif_int, 0));
    r_gmovi.fec_valor       := r_gmovi.fecha;
    r_gmovi.emi_aviso       := 'S';
    r_gmovi.reversado       := 'N';
    r_gmovi.protegido       := 'N';
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := v_cod_oficina;
    r_gmovi.cod_mod_padre   := 10;
    r_gmovi.cod_mad_padre   := v_cod_modalidad;
    --r_gmovi.cod_transaccion := 802;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);


    if nvl(v_dif_devengado, 0) > 0 then
      r_gmovi.cod_transaccion := 107;
    else
      r_gmovi.cod_transaccion := 108;
    end if;
    /*Generar el ajuste del devengado a la fecha desde el 01/01/YYYY hasta la fecha del proceso*/
    r_gmovi.nro_secuencia   := 2;
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := to_char(sysdate, 'HH24:MI:SS');
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.cod_modulo      := 10;
    r_gmovi.cod_modalidad   := v_cod_modalidad;
    r_gmovi.cod_oficina     := v_cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.est_cuenta      := null;
    r_gmovi.cod_tra_padre   := 300;
    r_gmovi.concepto        := 'Devengado ajustado';
    r_gmovi.monto           := abs(nvl(v_dif_devengado, 0));
    r_gmovi.fec_valor       := r_gmovi.fecha;
    r_gmovi.emi_aviso       := 'S';
    r_gmovi.reversado       := 'N';
    r_gmovi.protegido       := 'N';
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := v_cod_oficina;
    r_gmovi.cod_mod_padre   := 10;
    r_gmovi.cod_mad_padre   := v_cod_modalidad;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
  END;

-------------------------------------------------------------------------------
----Proceso de Actualización de Operaciones REPO
PROCEDURE PR_ACT_OPE_REPO(P_NRO_CUENTA     IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
                          P_ACCION         IN VARCHAR2,
                          P_NRO_SECUENCIA  IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE,
                          P_HORA           IN OUT GE_MOVIMIENTOS.HORA%TYPE) is

    --- Variables de tipo de registro
    r_pcta  md_cta_documentos%rowtype;
    r_ctarp md_cta_documentos%rowtype;
    r_ctadc md_cta_documentos%rowtype;
    r_gmovi ge_movimientos%rowtype;
    --- Variables para movimientos
    v_nro_secuencia ge_movimientos.nro_secuencia%type := P_NRO_SECUENCIA;
    v_hora          ge_movimientos.hora%type := P_HORA;
    v_cod_usuario   ge_movimientos.cod_usuario%type;
    --v_mto_interes        md_cta_documentos.mto_interes%type;
    v_error            varchar2(1000);
    v_mensaje          varchar2(1000);
    v_cotizacion       ge_cotizaciones.val_conversion%type;
    v_capital          md_cta_documentos.monto%type;
    v_cod_sit_contable md_cta_documentos.cod_sit_contable%type;
    v_cod_mon_local    ba_monedas.cod_moneda%type;
    ---
    v_cod_tra_cargo    number := 704; ----------------- Transaccion por cargo
    v_cod_tas_cargo    number;
    v_val_tas_cargo    number;
    v_val_cargo        number;
    v_cod_tra_impuesto number;
    v_cod_tas_impuesto number;
    v_val_tas_impuesto number;
    v_val_impuesto     number;
    --impuesto
    v_val_tas_iva  number;
    v_fec_vigencia date;
    v_redondeo     number(5);
    v_tip_valor    ge_tasas.tip_valor%type;
    v_tipo         ge_tasas.tipo%type;
    v_cod_tasa     ge_tasas.cod_tasa%type;
    v_concepto     ge_movimientos.concepto%type;
    v_fec_actual   ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(10);
    -- cuotas
    v_val_int_dev_cuota     md_cta_documentos.val_int_devengar%Type := 0;
    v_val_int_dev_dia_cuota md_cta_documentos.val_int_devengar%Type := 0; -- Diferencia devengado reclasificacion (Alta - Baja)
    v_val_int_dev_act_cuota md_cta_documentos.val_int_devengar%Type := 0; -- Devengado actual a la fecha
    v_mto_int_cuota         md_cta_documentos.mto_interes%Type := 0;
    v_val_compra            md_cta_documentos.monto%Type := 0;
    v_por_cuota             md_cuo_instrumentos.val_tas_porcentaje%Type := 0;
    v_dev_acumulado         md_cta_documentos.dev_acumulado%Type := 0;
    v_cod_transaccion       ge_movimientos.cod_transaccion%type;
    v_mov_cod_sit_contable  md_cta_documentos.cod_sit_contable%type;
    v_cta_sit_contable      md_cta_documentos.nro_cuenta%Type;
    v_can_automatica        Varchar2(1) := 'N';
    v_tip_persona           Varchar2(1) := 'B'; -- Por defecto valor de BCP para no generar factura
    v_mto_iva_interes       ge_movimientos.monto%type := 0;
    v_val_por_iva           number := 10;
    v_est_det_bono          md_cuo_instrumentos.estado%type := null;
    v_mto_cuota          md_cuo_instrumentos.mto_cuota%type;
      -- DATOS DE LAS CUENTAS INSTRUMENTOS --
    Cursor c_intrumentos is
      Select a.dev_acumulado, a.val_presente, a.val_int_devengar, a.monto, a.mto_interes int_documento,
             b.nro_cuenta,b.nro_cta_repo, b.estado, b.mto_cuota, b.mto_interes int_repo,
             b.mto_con_descuento, b.mto_presente, b.nro_cuota
        from md_cta_documentos a, md_cuo_instrumentos b
       Where a.nro_cuenta = b.nro_cuenta
         And b.nro_cta_repo = p_nro_cuenta;
  ---------------------------------------------------------------------------

  ---------------------------------------------------------------------------
  --------         INICIO:  Procesos Internos                       ---------
  ---------------------------------------------------------------------------

  ---Proceso para insertar movimientos REPO
  procedure pp_ins_movimiento(p_nro_rel_repo        in ge_movimientos.nro_cuenta%type,
                              p_nro_cta_debcre      in ge_movimientos.nro_cuenta%type default null,
                              p_cod_tra_padre       in ge_movimientos.cod_tra_padre%type,
                              p_cod_transaccion     in ge_movimientos.cod_transaccion%type,
                              p_concepto            in ge_movimientos.concepto%type,
                              p_nro_secuencia       in out ge_movimientos.nro_secuencia%type,
                              p_hora                in out ge_movimientos.hora%type,
                              p_monto               in ge_movimientos.monto%type default null,
                              p_est_cuenta          in ge_movimientos.estado%type default null,
                              p_referencia          in ge_movimientos.referencia%type default null,
                              p_sit_contable        in ge_movimientos.cod_sit_contable%type default null,
                              p_val_tasa            in ge_movimientos.val_tasa%type default null
                              ) is

  ---p_nro_rel_repo:     Nro. Cta. del REPO / Cuenta Instrumento
  ---p_nro_cta_debcre:   Nro. Cta. Débito / Crédito (solo modulos 3 y 4)
  ---p_cod_tra_padre:    Cód. trans Padre
  ---p_cod_transaccion:  Cód. trans hijo
  ---p_concepto:         Concepto del movimiento
  ---p_nro_secuencia     Nro. de secuencia
  ---p_hora              hora
  ---p_monto             monto
  ---p_est_cuenta        estado de la cuenta si corresponde
  ---p_referencia        referencia si corresponde


  rp_rdocu            md_cta_documentos%Rowtype;
  rp_rctdc            ge_cuentas%Rowtype;
  v_nro_secuencia     ge_movimientos.nro_secuencia%type;
  v_hora              ge_movimientos.hora%type := nvl(p_hora, to_char(sysdate, 'HH24:MI:SS'));
  v_fec_actual        ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(10);
  v_redondeo          number;

Begin
--------------------
--INICIO: PROCESO --
--------------------

----------INICIO: Buscar datos -----------------------------------------------
  begin
    select *
      into rp_rdocu
      from md_cta_documentos sg
     where sg.nro_cuenta = p_nro_rel_repo;
  exception
    when no_data_found then
      raise_application_error(-20000, 'No existe Cuenta: '||p_nro_rel_repo);
    when others then
      raise_application_error(-20001, 'En Busqueda de Cuenta: '||p_nro_rel_repo);
  end;

  If p_nro_cta_debcre is not null then
      begin
        select *
          into rp_rctdc
          from ge_cuentas g
         where g.nro_cuenta = p_nro_cta_debcre;
      exception
        when no_data_found then
          raise_application_error(-20002, 'No existe Cuota de Cuenta: '||p_nro_cta_debcre);
        when others then
          raise_application_error(-20003, 'En Busqueda de Cuota de la Cuenta: '||p_nro_cta_debcre);
      end;
  End if;
  --Decimales para redondeo por Moneda
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',10,r_pcta.cod_modalidad,r_pcta.cod_moneda);
  --Asignar valor a código de oficina
  v_nro_secuencia := nvl(p_nro_secuencia, 0);
  v_nro_secuencia := v_nro_secuencia + 1;

----------FIN: Buscar datos -----------------------------------------------

    --- Generar movimiento
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.cod_modulo      := nvl(rp_rctdc.cod_modulo, rp_rdocu.cod_modulo);
    r_gmovi.cod_modalidad   := nvl(rp_rctdc.cod_modalidad, rp_rdocu.cod_modalidad);
    r_gmovi.cod_oficina     := rp_rdocu.cod_oficina;
    r_gmovi.nro_cuenta      := nvl(p_nro_cta_debcre,p_nro_rel_repo);
    r_gmovi.cod_moneda      := nvl(rp_rctdc.cod_moneda, rp_rdocu.cod_moneda);
    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_transaccion := p_cod_transaccion;
    r_gmovi.fec_valor       := v_fec_actual;
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.reversado       := 'N';
    r_gmovi.protegido       := 'N';
    r_gmovi.estado          := 'N';
    r_gmovi.concepto        := p_concepto;
    r_gmovi.cod_ofi_origen  := rp_rdocu.cod_oficina;
    r_gmovi.cod_mod_padre   := rp_rdocu.cod_modulo;
	IF rp_rdocu.cod_modalidad = 149 THEN
       r_gmovi.cod_mad_padre   := rp_rdocu.cod_modalidad;
	ELSE
       r_gmovi.cod_mad_padre   := rp_rdocu.cod_modalidad;
	END IF;
    r_gmovi.nro_documento   := rp_rdocu.nro_cuenta;
    r_gmovi.cod_sit_contable := p_sit_contable;
    r_gmovi.monto            := null;

    If p_est_cuenta is not null then
       r_gmovi.est_cuenta      := p_est_cuenta;
    End if;

    If p_monto is not null then


      --------- MONTO MOV. ****************
      --- busco el valor de la cotizacion
      v_cod_mon_local := pag_gen.fu_obt_mon_local;
      v_cotizacion    := null;
      if rp_rdocu.cod_moneda <> v_cod_mon_local then
         --- Actualizar cargos a la cotizacion del dia.
         v_cotizacion := fug_obt_cotizacion(rp_rdocu.cod_moneda, v_fec_actual);
         r_gmovi.cotizacion      := v_cotizacion;
         r_gmovi.mto_equ_local   := round(NVL(p_monto * v_cotizacion,0), 0);
         r_gmovi.monto := round(p_monto,v_redondeo);
      Else
         r_gmovi.monto := round(p_monto,v_redondeo);
      end if;
              --*****************--
    End if;

    if p_val_tasa is not null then
       r_gmovi.val_tasa := p_val_tasa;
    else
       r_gmovi.val_tasa := null;
    end if;

    -----PROCESO PRINCIPAL - INSERTA LOS MOVIMIENTOS-----------
            pag_gen.pr_ins_ge_movimiento(r_gmovi);
    ----------------------------------------------------------

     p_nro_secuencia := v_nro_secuencia;
     p_hora          := v_hora;
  exception
    when others then
            raise_application_error(-20000, 'Inserción Movimiento Relacionado a REPO: '||rp_rdocu.nro_cuenta||' - '||sqlerrm );

  end pp_ins_movimiento;


  -- **** Procedimiento Interno: Actualizar las Cuentas Repo y cuotas Repo **** --
  procedure pp_act_cuenta(p_nro_cuenta    in md_cta_documentos.nro_cuenta%type,
                          p_estado        in md_cta_documentos.estado%type,
                          p_nro_secuencia in out ge_movimientos.nro_secuencia%type,
                          p_hora          in out ge_movimientos.hora%type) is

  v_nro_secuencia     ge_movimientos.nro_secuencia%type := nvl(p_nro_secuencia,0);
  v_hora              ge_movimientos.hora%Type := p_hora;
  v_nro_cuenta        ge_movimientos.nro_cuenta%type := p_nro_cuenta;

  begin

    ----Actualiza Situacion de la Cuenta Repo ---------
    v_cod_sit_contable := pab_asi.fu_cal_sit_contable(v_nro_cuenta);

    --- Actualiza la Cuenta Repo ---
    if p_estado='N' then
      --TTCE-85
     begin
        update md_cta_documentos p
           set p.estado = p_estado,
               p.cod_sit_contable = v_cod_sit_contable
         where p.nro_cuenta = v_nro_cuenta;
      exception
        when others then
           raise_application_error(-20000, 'Actualización Situación Doc. REPO: '||v_nro_cuenta);
      end;
    else
      begin
        update md_cta_documentos p
           set p.estado = p_estado,
               p.cod_sit_contable = v_cod_sit_contable,
               p.val_int_devengar = p.mto_interes
         where p.nro_cuenta = v_nro_cuenta;
      exception
        when others then
           raise_application_error(-20000, 'Actualización Situación Doc. REPO: '||v_nro_cuenta);
      end;
    end if;
     

      --- Actualiza estado de Cuenta Cuota Repo ---
      begin
         update md_cuo_instrumentos pri
            set pri.estado     = p_estado
          where pri.nro_cuenta = v_nro_cuenta
            and pri.nro_cuota = 1;
      exception
        when others then
           raise_application_error(-20001,'Actualización Estado Doc. Rel. REPO: ' ||v_nro_cuenta);
      end;

     v_nro_secuencia := v_nro_secuencia + 1;
     ---Movimiento por el Cambio de Estado
     pp_ins_movimiento(v_nro_cuenta,               --Nro. Cta. del REPO-(p_nro_rel_repo)
                       null,                       --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_cta_debcre)
                       401,                        --Cód. trans Padre-(p_cod_tra_padre)
                       401,                        --Cód. trans hijo-(p_cod_transaccion)
                       'Cambio de Estado',          --Concepto del movimiento-(p_concepto)
                       v_nro_secuencia,            --Nro. de secuencia-(p_nro_secuencia)
                       v_hora,                     --hora-(p_hora)
                       null,                       --monto-(p_monto)
                       p_estado,                   --estado de la cuenta si corresponde-(p_est_cuenta)
                       null,                       --referencia-(p_referencia)
                       null,                       -- Situacion contable
                       null);                      -- Valor tasa (IVA)


        p_nro_secuencia := v_nro_secuencia;
        p_hora          := v_hora;


  exception
    when others then
       raise_application_error(-20001, 'Actualiza Cuenta Doc. REPO: '||v_nro_cuenta);
  end pp_act_cuenta;

--------------------------------------------------------------------------------------------------------------
----Procedimiento Interno - Proposito: Actualizar estado de cabecera de acuerdo al saldo_disponible  e inserta movimiento
  procedure pp_act_doc_cabecera (p_cta_repo       in md_cta_documentos.nro_cuenta%type,
                                 p_nro_secuencia       in out ge_movimientos.nro_secuencia%type,
                                 p_hora                in out ge_movimientos.hora%type) is
  -- Actualizar Documentos Relacionados al REPO --
  Cursor c_doc_cabecera is
    select r.nro_cuenta, r.nro_cta_repo, d.sal_disponible, d.estado
      from md_cuo_instrumentos r, md_cta_documentos d
     where r.nro_cuenta = d.nro_cuenta
       and r.nro_cta_repo = p_cta_repo;

  v_nro_secuencia        ge_movimientos.nro_secuencia%type := nvl(p_nro_secuencia,0);
  v_hora                 ge_movimientos.hora%Type := p_hora;
  v_nro_cuenta           ge_movimientos.nro_cuenta%type := p_cta_repo;
  v_est_cta_relacionada  Varchar2(1);

 begin
    -- Actualizamos los estados de instrumentos de acuerdo al saldo disponible
    for c_doc in c_doc_cabecera Loop

              -- Documentos --
      If NVL(c_doc.sal_disponible,0) <= 0 Then

          ----Actualiza Situacion de la Cuenta Instrumento ---------
          v_cod_sit_contable := pab_asi.fu_cal_sit_contable(v_nro_cuenta);
          v_est_cta_relacionada :=  'R';
          --- Actualiza estado de Cuenta Instrumento ---
          begin
            update md_cta_documentos p
               set p.estado = v_est_cta_relacionada,  -- cuando no tiene saldo disponible el instrumento queda en ripeado y no se utiliza mas en ningun repo
                   p.cod_sit_contable = v_cod_sit_contable
             where p.nro_cuenta = c_doc.nro_cuenta;
          exception
            when others Then
               raise_application_error(-20000, 'Actualiza estado Md_cta_documentos REPO: '||v_nro_cuenta);
          end;

          -- Modificamos el estado de la cuota 1 --
            begin
              update md_cuo_instrumentos d
                 set d.estado = 'N'
               where d.nro_cuenta = c_doc.nro_cuenta
                 And d.nro_cuota = 1;
            exception
              when others then
                RAISE_APPLICATION_ERROR( -20000, 'Error cambio de estado en MD_CUO_INTRUMENTOS. Nro. Cta.:'||c_doc.nro_cuenta||sqlerrm );
            end;

           v_nro_secuencia := v_nro_secuencia + 1;
           ---Movimiento por el Cambio de Estado
           pp_ins_movimiento(c_doc.nro_cuenta,           --Nro. Cta. del REPO-(p_nro_rel_repo)
                             null,                       --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_cta_debcre)
                             401,                        --Cód. trans Padre-(p_cod_tra_padre)
                             401,                        --Cód. trans hijo-(p_cod_transaccion)
                             'Cambio de Estado',          --Concepto del movimiento-(p_concepto)
                             v_nro_secuencia,            --Nro. de secuencia-(p_nro_secuencia)
                             v_hora,                     --hora-(p_hora)
                             null,                       --monto-(p_monto)
                             v_est_cta_relacionada,      --estado de la cuenta si corresponde-(p_est_cuenta)
                             null,                       --referencia-(p_referencia)
                             null,                       -- Situacion contable
                             null);                      -- Valor tasa (IVA)


            p_nro_secuencia := v_nro_secuencia;
            p_hora          := v_hora;

      Elsif NVL(c_doc.sal_disponible,0) > 0 And c_doc.estado = 'R' Then

             ----Actualiza Situacion de la Cuenta Instrumento ---------
          v_cod_sit_contable := pab_asi.fu_cal_sit_contable(c_doc.nro_cuenta);
          v_est_cta_relacionada :=  'C';
          --- Actualiza estado de Cuenta Instrumento ---
          begin
            update md_cta_documentos p
               set p.estado = v_est_cta_relacionada, -- pasa a estado vigente cuando tiene saldo disponible
                   p.cod_sit_contable = v_cod_sit_contable
             where p.nro_cuenta = c_doc.nro_cuenta;
          exception
            when others Then
               raise_application_error(-20000, 'Actualiza Instrumento REPO: '||v_nro_cuenta);
          end;

           v_nro_secuencia := v_nro_secuencia + 1;
           ---Movimiento por el Cambio de Estado
           pp_ins_movimiento(c_doc.nro_cuenta,           --Nro. Cta. del REPO-(p_nro_rel_repo)
                             null,                       --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_cta_debcre)
                             401,                        --Cód. trans Padre-(p_cod_tra_padre)
                             401,                        --Cód. trans hijo-(p_cod_transaccion)
                             'Cambio de Estado',          --Concepto del movimiento-(p_concepto)
                             v_nro_secuencia,            --Nro. de secuencia-(p_nro_secuencia)
                             v_hora,                     --hora-(p_hora)
                             null,                       --monto-(p_monto)
                             v_est_cta_relacionada,      --estado de la cuenta si corresponde-(p_est_cuenta)
                             null,                       --referencia-(p_referencia)
                             null,                       -- Situacion contable
                             null);                      -- Valor tasa (IVA)


            p_nro_secuencia := v_nro_secuencia;
            p_hora          := v_hora;

      End If;

    end loop;

    p_nro_secuencia := v_nro_secuencia;
    p_hora          := v_hora;

  exception
    when others then
         raise_application_error(-20000, 'Actualización Doc. Cabecera en REPO: '||p_cta_repo);
  end pp_act_doc_cabecera;

  ---------------------------------------------------------------------------
  ----Procedimiento Interno - Proposito: Actualizar tablas de documentos relacionados e insertar movimientos
  procedure pp_act_doc_relacionados(p_cta_principal       in md_cta_documentos.nro_cuenta%type,
                                    p_est_cta_principal   in md_cta_documentos.estado%type,
                                    p_est_cta_relacionada in md_cta_documentos.estado%type DEFAULT NULL,
                                    p_est_ope_det         in md_cuo_instrumentos.estado%type,
                                    p_est_doc_cuota       in md_cta_documentos.estado%type DEFAULT NULL,
                                    p_nro_secuencia       in out ge_movimientos.nro_secuencia%type,
                                    p_hora                in out ge_movimientos.hora%type) is
  -- Actualizar Documentos Relacionados al REPO --
  Cursor c_doc_relacionados is
    select r.nro_cuenta, r.nro_cta_repo, d.sal_disponible
      from md_cuo_instrumentos r, md_cta_documentos d
     where r.nro_cuenta = d.nro_cuenta
       and r.nro_cta_repo = p_cta_principal;

  v_nro_secuencia     ge_movimientos.nro_secuencia%type := nvl(p_nro_secuencia,0);
  v_hora              ge_movimientos.hora%Type := p_hora;
  v_nro_cuenta        ge_movimientos.nro_cuenta%Type;

 begin
    -- Actualizamos los instrumentos
    for c_doc in c_doc_relacionados Loop

        -- Cuotas --
        If p_est_doc_cuota is not null Then
          --Actualiza estado de Cuenta
          begin
            update md_cuo_instrumentos cuo
               set cuo.estado       = p_est_doc_cuota
                   --,cuo.nro_cta_repo = decode(p_est_doc_cuota,'C', null,cuo.nro_cta_repo)
             where cuo.nro_cuenta = c_doc.nro_cuenta
               and nvl(cuo.nro_cta_repo, 'X') = nvl(c_doc.nro_cta_repo, 'X');
          exception
            when others then
              raise_application_error(-20000,
                                      'Actualización Cuota Doc. REPO: ' ||
                                      c_doc.nro_cta_repo);
          end;
        End if;
    end loop;

    -- Documentos --
    If p_est_cta_relacionada is not null then
       pp_act_doc_cabecera (p_cta_principal,
                            v_nro_secuencia,
                            v_hora);
    End If;

    p_nro_secuencia := v_nro_secuencia;
    p_hora          := v_hora;

  exception
    when others then
         raise_application_error(-20000, 'Actualización Doc. Relacionado a REPO: '||p_cta_principal);
  end pp_act_doc_relacionados;

  ---------------------------------------------------------------------------
  -- Procedimiento Interno: Generar movimiento por la Compra de Documentos al dar de Baja un REPO --
 procedure pp_ins_com_documentos (p_cta_documento   In md_cta_documentos.nro_cuenta%Type,
                                  p_mto_compra      In md_cta_documentos.monto%Type,
                                  p_nro_secuencia   in out ge_movimientos.nro_secuencia%type,
                                  p_hora            in out ge_movimientos.hora%type) is

  v_lugar          varchar2(500);
  v_redondeo       number(5);
  v_mto_credito    md_cta_documentos.monto%type;
  r_gmovi          ge_movimientos%rowtype;
  v_fec_actual     ge_movimientos.fecha%type := pag_cal.FU_OBT_FEC_ACTUAL(10);
  v_nro_secuencia  ge_movimientos.nro_secuencia%type := nvl(p_nro_secuencia,0);
  v_hora           ge_movimientos.hora%Type := nvl(p_hora, to_char(Sysdate,'hh24:mm:ss'));
  v_transaccion    ge_movimientos.cod_transaccion%type := 602;
  v_impuesto       ge_movimientos.monto%type;
  v_cod_moneda     ge_movimientos.cod_moneda%type;
  v_cod_ofi_origen ge_movimientos.cod_oficina%type;
  v_cotizacion     ge_movimientos.cotizacion%type;

  /*Inicio*/
 begin
    v_lugar := 'Inicio pp_ins_com_documentos';
    v_cod_ofi_origen := FUG_OBT_OFI_USUARIO(user);

    -- Obtenemos los datos de la cuenta documento --
    pam_doc.pr_obt_datos(p_cta_documento, r_ctadc);

    v_impuesto := 0;

    v_cotizacion := null;
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 10, r_ctadc.cod_modalidad, r_ctadc.cod_moneda );

    --- Verificar cotizacion
    if r_ctadc.cod_moneda <> pag_gen.fu_obt_mon_local then
       v_lugar      := 'pag_gen.fu_obt_cotizacion';
       v_cotizacion := fug_obt_cotizacion(r_ctadc.cod_moneda,v_fec_actual);
    end if;

    -- Forma de pago se toma del Repo --
    v_lugar := 'Formas de pago';
    if r_pcta.for_pago = 'C' then ---Credito en Cta.
       pag_cta.pr_obt_cuenta(r_pcta.nro_ref_credito);
    elsif r_pcta.for_pago = 'R' then   --Credito en Cta. Contable
       v_lugar := 'Obtiene Mon. Rub.Contable';
       begin
          select cod_moneda
            into v_cod_moneda
            from cb_rubros
           where cod_rubro = r_pcta.nro_ref_credito
             and imputable = 'S';
       exception
          when no_data_found then
            raise_application_error(-20000,v_lugar||'-'||pag_cta.fu_obt_msj_error());
       end;
     End if;
  ------------------------------------------------

    v_mto_credito := p_mto_compra;
    r_gmovi.cod_sit_contable := r_ctadc.cod_sit_contable;

  --- Forma de pago ---
  if r_pcta.nro_ref_credito is not null and r_pcta.for_pago = 'C' then   ---Credito en Cta.
     v_lugar := 'prg_ver_cob_cargos';
     v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
     --calcula impuesto si corresponde y genera movimiento
     prg_ver_cob_cargos(r_pcta.nro_ref_credito,
                        r_ctadc.nro_cuenta,
                        r_ctadc.cod_modulo,
                        r_ctadc.cod_modalidad,
                        v_cod_ofi_origen,
                        pag_cta.g_ctas.cod_moneda,
                        abs(v_mto_credito),
                        'Compra Documento - Mto. Repo ' || r_ctadc.nro_cuenta,
                        null,--nro_documento
                        v_fec_actual,
                        v_hora,
                        v_impuesto,
                        v_nro_secuencia,
                        'S',-- procesar si
                        v_cotizacion);

     -- Actualiza la Cuenta Crédito / Destino
     v_lugar := 'pag_cta.pr_act_operacion';
     if nvl(v_impuesto,0) <> 0 then
        v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
     end if;
     pag_cta.pr_act_operacion( r_pcta.nro_ref_credito,
                               v_hora,---------------------------- HORA
                               'C',
                               pag_cta.g_ctas.cod_moneda,------- Moneda de la Operación
                               v_mto_credito - nvl(v_impuesto, 0),
                               101,----------------------------- COD_TRA_PADRE (Desembolso de Préstamo)
                               v_transaccion,
                               r_ctadc.nro_cuenta,
                               v_cotizacion,-------------------- COTIZACION
                               v_cod_ofi_origen,---------------- cod_ofi_origen
                               r_ctadc.cod_modulo,-------------- cod_mod_padre
                               r_ctadc.cod_modalidad,----------- cod_mad_padre
                               null,---------------------------- cod_tasa
                               null,---------------------------- val_tasa
                               'Compra Documento - Mto. Repo ' ||r_ctadc.nro_cuenta,
                               'S',----------------------------- emi_aviso
                               v_nro_secuencia,
                               v_fec_actual);

     if pag_cta.fu_obt_cod_error() <> 0 then
        raise_application_error(-20000,v_lugar||'-'||pag_cta.fu_obt_msj_error());
     end if;
   elsif r_pcta.nro_ref_credito is not null and r_pcta.for_pago = 'R' then --Credito en Cta. Contable
      v_lugar := 'pag_gen.pr_ins_ge_movimiento';
      v_nro_secuencia         := v_nro_secuencia + 1;

      r_gmovi.cod_usuario     := user;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_modulo      := r_ctadc.cod_modulo;
      r_gmovi.cod_modalidad   := r_ctadc.cod_modalidad;
      r_gmovi.cod_oficina     := nvl(r_ctadc.cod_ofi_credito,v_cod_ofi_origen);
      r_gmovi.cod_moneda      := v_cod_moneda;
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.cod_tra_padre   := 101;
      r_gmovi.cod_mod_padre   := r_ctadc.cod_modulo;
      r_gmovi.cod_mad_padre   := r_ctadc.cod_modalidad;
      r_gmovi.cod_transaccion := 741;
      r_gmovi.monto           := v_mto_credito;
      r_gmovi.nro_documento   := r_ctadc.nro_cuenta;
      r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Compra Documento - Mto. Repo ' ||r_ctadc.nro_cuenta;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_rubro       := r_pcta.nro_ref_credito;
      r_gmovi.nro_cuenta      := null;
      r_gmovi.tip_mov_rubro   := 'C';
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * nvl(v_cotizacion,0));
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   end if;

  p_nro_secuencia := v_nro_secuencia;
  p_hora          := v_hora;

  exception
    when others then
         raise_application_error(-20000, 'Inserta Mov. Compra Documento Ripeado: '||r_ctadc.nro_cuenta||' - '||sqlerrm);
  end pp_ins_com_documentos;
  ---------------------------------------------------------------------------
  --------            FIN : Procesos Internos                        ---------
  ---------------------------------------------------------------------------


  BEGIN

    ---------------------------------------------------------
                -- INICIO - PROCESO PRINCIPAL --
    ---------------------------------------------------------

    --- Recuperar datos de la Operación (Cuenta Principal REPO)
    pam_doc.pr_obt_datos(p_nro_cuenta, r_pcta);
    ---                      ----                          ----

    ---------------------------------------------------------
    -- Actualizaciones de Cuentas / Generación Movimientos --
    ---------------------------------------------------------

             ---> Modalidad: REPO RECIBIDO <---

    --If r_pcta.cod_modalidad = 127 then
    If FUM_OBT_OPE_REPO(r_pcta.cod_modulo,r_pcta.cod_modalidad,'S','R') = 'S' then

      v_cod_sit_contable := Null;
      --******************************************************--
           ---> Confirmación REPO RECIBIDO
      --******************************************************--
      If p_accion = 'VE' then
         -- Actualizamos la Cuenta Repo y la de los Instrumentos --
         v_mensaje := 'Actualiza Cta Repo - VE.';
         pp_act_cuenta(r_pcta.nro_cuenta,                          --Se envia el nro. de Cuenta REPO - (p_nro_cuenta)
                       'E',                                        --Estado al que se deberá actualizar la Cuenta REPO: E-REPO-(p_estado)
                       v_nro_secuencia,                            --Número de Secuencia para Inserción de Movimientos-(p_nro_secuencia)
                       v_hora);                                    --Hora para Inserción de Movimientos - (p_hora)

         v_mensaje := 'Actualiza Doc. Rel. Repo - VE.';
         pp_act_doc_relacionados(r_pcta.nro_cuenta,                --Se envia el nro. de Cuenta REPO - (p_cta_principal)
                                 Null,                             --(OBS: se actualiza en pp_act_cuenta) Estado al que se deberá actualizar la Cuenta REPO: E-REPO-(p_estado)
                                 'R',                              --Estado para las Ctas. de Documentos Relac (md_cta_documentos): R-Ripeado-(p_est_cta_relacionada)
                                 Null,                             --(OBS: tabla sin estado) Estado al que se deberá actualizar (md_instrumentos_det): R-Ripeado-(p_est_ope_det)
                                 'R',                              --Estado al que se deberá la Cuota de cada documento (md_cuo_instrumentos): R-Ripeado-(p_est_doc_cuota)
                                 v_nro_secuencia,                  --Número de Secuencia para Inserción de Movimientos
                                 v_hora);                          --Hora para Inserción de Movimientos
         ---------------------------------------------------------
              -- Generamos los Movimientos Correspondientes --
         ---------------------------------------------------------
         v_cod_sit_contable := pab_asi.fu_cal_sit_contable(r_pcta.nro_cuenta);
         -- Venta Repo Interbancario - 811
         If nvl(r_pcta.monto,0) > 0 Then
           v_mensaje := 'Inserta Mov 811 - Monto Repo - VE.';
           pp_ins_movimiento(r_pcta.nro_cuenta,                                 --Nro. Cta. del REPO-(p_nro_rel_repo)
                             null,                                              --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                             102,                                               --Cód. trans Padre  -(p_cod_tra_padre)
                             811,                                               --Cód. trans hijo-(p_cod_transaccion)
                             'Confirma REPO Recibido - Capital '||r_pcta.nro_cuenta,  --Concepto del movimiento-(p_concepto)
                             v_nro_secuencia,                                   --Nro. de secuencia-(p_nro_secuencia)
                             v_hora,                                            --hora -(p_hora)
                             r_pcta.monto,                                      --monto-(p_monto)
                             null,                                              --estado de la cuenta si corresponde-(p_est_cuenta)
                             null,                                              --referencia si corresponde-(p_referencia)
                             v_cod_sit_contable,                                --Cód. Situacion contable-(p_cod_sit_contable)
                             null);
         End if;

         -- Interes Repo - 812
         If nvl(r_pcta.mto_interes,0) > 0 Then
           v_mensaje := 'Inserta Mov 812 - Interes REPO - VE.';
           pp_ins_movimiento(r_pcta.nro_cuenta,                          --Nro. Cta. del REPO-(p_nro_rel_repo)
                             null,                                       --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                             102,                                        --Cód. trans Padre  -(p_cod_tra_padre)
                             812,                                        --Cód. trans hijo-(p_cod_transaccion)
                             'Interes REPO Recibido '||r_pcta.nro_cuenta,--Concepto del movimiento-(p_concepto)
                             v_nro_secuencia,                            --Nro. de secuencia-(p_nro_secuencia)
                             v_hora,                                     --hora -(p_hora)
                             r_pcta.mto_interes,                         --monto-(p_monto)
                             null,                                       --estado de la cuenta si corresponde-(p_est_cuenta)
                             Null,                                       --referencia si corresponde-(p_referencia)
                             v_cod_sit_contable,                         --Cód. Situacion contable-(p_cod_sit_contable)
                             null);
         End if;
         
         begin
           select m.mto_cuota 
            into v_mto_cuota
           from md_cuo_instrumentos m
           where m.nro_cta_repo = r_pcta.nro_cuenta;
         Exception
               When Others Then
                 v_mto_cuota := 0;
         end;
         
          If nvl(v_mto_cuota,0) > 0 Then
           v_mensaje := 'Alta de garantia 803 - VE.';
           pp_ins_movimiento(r_pcta.nro_cuenta,                          --Nro. Cta. del REPO-(p_nro_rel_repo)
                             null,                                       --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                             102,                                        --Cód. trans Padre  -(p_cod_tra_padre)
                             803,                                        --Cód. trans hijo-(p_cod_transaccion)
                             'Alta de garantia '||r_pcta.nro_cuenta,--Concepto del movimiento-(p_concepto)
                             v_nro_secuencia,                            --Nro. de secuencia-(p_nro_secuencia)
                             v_hora,                                     --hora -(p_hora)
                             v_mto_cuota,                         --monto-(p_monto)
                             null,                                       --estado de la cuenta si corresponde-(p_est_cuenta)
                             Null,                                       --referencia si corresponde-(p_referencia)
                             v_cod_sit_contable,                         --Cód. Situacion contable-(p_cod_sit_contable)
                             null);
         End if;

         -- Cursor de instrumentos relacionados
         for c_ins in c_intrumentos Loop

              -- Hallamos el porcentaje de la cuota con respecto al monto del intrumento --
              v_por_cuota := nvl((nvl(c_ins.mto_cuota,0) * 100) / nvl(c_ins.monto,0),0);

              --------------------------------------------------------------
             /* If nvl(c_ins.val_int_devengar,0) > 0 Then
                 -- Hallamos el monto de acuerdo al porcentaje de valor de cuota
                 v_val_int_dev_cuota := NVL((nvl(c_ins.val_int_devengar,0) * v_por_cuota) / 100,0);
                 --  Interes a Devengar - 802 / Se generan datos de cobro de intereses
                 v_mensaje := 'Inserta Venta Documento 802 - VE.';
                 pp_ins_movimiento(c_ins.nro_cuenta,                                        --Nro. Cta. Instrumento-(p_nro_rel_repo)
                                   null,                                                    --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   102,                                                     --Cód. trans Padre  -(p_cod_tra_padre)
                                   802,                                                     --Cód. trans hijo-(p_cod_transaccion)
                                   'Venta de Documento - Int. Devengar '||c_ins.nro_cuenta,        --Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                                 --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                          --hora -(p_hora)
                                   v_val_int_dev_cuota,                             --monto-(p_monto)
                                   null,                                            --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                            --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                              --Cód. Situacion contable-(p_cod_sit_contable)
                                   null);

                 -- Alta Interes a Devengar Reclasificacion Instrumentos --
                 Update md_cuo_instrumentos ci
                    Set ci.val_int_cuo_devengar = v_val_int_dev_cuota
                  Where ci.nro_cuenta   = c_ins.nro_cuenta
                    And ci.nro_cuota    = c_ins.nro_cuota
                    And ci.nro_cta_repo = c_ins.nro_cta_repo;

              End If;*/
              --------------------------------------------------------------
              If nvl(c_ins.mto_cuota,0) > 0 and nvl(r_pcta.cod_modalidad,0) != 149 Then --TN-929 GMPEREIRA no se insertan movimientos para REPO Bursatil
                --Valor de la Venta del documento - inserta val_presente de la Venta del Doc.
                v_mto_int_cuota := c_ins.mto_cuota;--NVL((nvl(c_ins.int_documento,0) * v_por_cuota) / 100,0);
                --  Venta Documento - 805 Capital proporcional del Documento
                 v_mensaje := 'Alta de garantia 804 - VE.';
                 pp_ins_movimiento(c_ins.nro_cuenta,                                  --Nro. Cta. del Instrumento-(p_nro_rel_repo)
                                   null,                                 --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   102,                                               --Cód. trans Padre  -(p_cod_tra_padre)
                                   804,                                               --Cód. trans hijo-(p_cod_transaccion)
                                   'Alta de garantia '||c_ins.nro_cuenta,           --Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                                   --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                            --hora -(p_hora)
                                   nvl(v_mto_int_cuota,0),        --monto-(p_monto)
                                   null,                                              --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                              --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                                --Cód. Situacion contable-(p_cod_sit_contable)
                                   null);
              End If;
              --------------------------------------------------------------
             /* If nvl(c_ins.int_documento,0) > 0 Then
               -- Hallamos el monto de acuerdo al porcentaje de valor de cuota
                 v_mto_int_cuota := NVL((nvl(c_ins.int_documento,0) * v_por_cuota) / 100,0);

               --  Venta Documento - 817 - Afecta Interes del documento
                 v_mensaje := 'Inserta Venta Documento 817 - VE.';
                 pp_ins_movimiento(c_ins.nro_cuenta,                               --Nro. Cta. del Instrumento-(p_nro_rel_repo)
                                   null,                                           --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   102,                                            --Cód. trans Padre  -(p_cod_tra_padre)
                                   817,                                            --Cód. trans hijo-(p_cod_transaccion)
                                   'Venta de Documento - Interes '||c_ins.nro_cuenta,--Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                                --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                         --hora -(p_hora)
                                   v_mto_int_cuota,                                --monto-(p_monto)
                                   null,                                           --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                           --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                             --Cód. Situacion contable-(p_cod_sit_contable)
                                   null);
              End If;*/
         End Loop;
      -----------------------------------------------------------------------------------------
      --******************************************************--
           ---> Cancelación REPO RECIBIDO
      --******************************************************--
      Elsif p_accion = 'CV' then

        If r_pcta.estado =  'E' Then
             --- Cancelamos el Repo ---
             v_mensaje := 'Actualiza Cta - CV.';
             pp_act_cuenta(r_pcta.nro_cuenta,                          --Se envia el nro. de Cuenta REPO - (p_nro_cuenta)
                           'N',                                        --Estado al que se deberá actualizar la Cuenta REPO: N-Cancelado-(p_estado)
                           v_nro_secuencia,                            --Número de Secuencia para Inserción de Movimientos-(p_nro_secuencia)
                           v_hora);                                    --Hora para Inserción de Movimientos - (p_hora)

             --- Hallamos el cod_sit_contable para los movimientos --
             Begin
                Select a.nro_cuenta
                  Into v_cta_sit_contable
                  from md_cuo_instrumentos a
                 Where a.nro_cta_repo = r_pcta.nro_cuenta
                   And Rownum = 1;
             Exception
               When Others Then
                 v_cta_sit_contable := r_pcta.nro_cuenta;
             End;

             If v_cta_sit_contable <> r_pcta.nro_cuenta Then
                v_cod_sit_contable := pab_asi.fu_cal_sit_contable(v_cta_sit_contable);
             Else
                v_cod_sit_contable := '10000000';
             End If;

             ---------------------------------------------------------
                  -- Generamos los Movimientos Correpondientes --
             ---------------------------------------------------------
             --  Venta Documento REPO - 806 --
             If (nvl(r_pcta.monto,0) - nvl(r_pcta.mto_interes,0)) > 0 Then
                -- Valor de la Compra - inserta capital original de la compra
                v_mensaje := 'Inserta Venta Documento Repo 806 - CV.';

                pp_ins_movimiento(r_pcta.nro_cuenta,                              --Nro. Cta. REPO-(p_nro_rel_repo)
                                  null,                                           --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                  102,                                            --Cód. trans Padre  -(p_cod_tra_padre)
                                  806,                                            --Cód. trans hijo-(p_cod_transaccion)
                                  'Venta de Documento - Mto. Repo'||r_pcta.nro_cuenta,       --Concepto del movimiento-(p_concepto)
                                  v_nro_secuencia,                                --Nro. de secuencia-(p_nro_secuencia)
                                  v_hora,                                         --hora -(p_hora)
                                  nvl(r_pcta.monto,0)/* - nvl(r_pcta.mto_interes,0)*/,--monto-(p_monto)
                                  null,                                           --estado de la cuenta si corresponde-(p_est_cuenta)
                                  null,                                           --referencia si corresponde-(p_referencia)
                                  v_cod_sit_contable,                             --Cód. Situacion contable-(p_cod_sit_contable)
                                  null);
             End If;
             ---If nvl(r_pcta.mto_interes,0) > 0 Then
             If nvl(r_pcta.val_int_devengar,0)> 0 Then--TTCE-85
               -- Hallamos el monto de acuerdo al porcentaje de valor de cuota
                 --v_mto_int_cuota := NVL((nvl(c_ins.int_documento,0) * v_por_cuota) / 100,0);

               --  Venta Documento - 814 - Afecta Interes
                 v_mensaje := 'Inserta Venta Documento 814 - CD.';
                 pp_ins_movimiento(r_pcta.nro_cuenta,                               --Nro. Cta. del Instrumento-(p_nro_rel_repo)
                                   null,                                           --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   102,                                            --Cód. trans Padre  -(p_cod_tra_padre)
                                   814,                                            --Cód. trans hijo-(p_cod_transaccion)
                                   'Compra REPO - Intere Instrumento '||r_pcta.nro_cuenta,               --Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                                --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                         --hora -(p_hora)
                                   r_pcta.mto_interes,                                --monto-(p_monto)
                                   null,                                           --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                           --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                             --Cód. Situacion contable-(p_cod_sit_contable)
                                   null);
              End If;
              
               begin
                 select m.mto_cuota 
                  into v_mto_cuota
                 from md_cuo_instrumentos m
                 where m.nro_cta_repo = r_pcta.nro_cuenta;
               Exception
               When Others Then
                 v_mto_cuota := 0;
              end;
         
          If nvl(v_mto_cuota,0) > 0 Then
           v_mensaje := 'Baja de garantia 815 - VE.';
           pp_ins_movimiento(r_pcta.nro_cuenta,                          --Nro. Cta. del REPO-(p_nro_rel_repo)
                             null,                                       --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                             102,                                        --Cód. trans Padre  -(p_cod_tra_padre)
                             815,                                        --Cód. trans hijo-(p_cod_transaccion)
                             'Baja de garantia '||r_pcta.nro_cuenta,--Concepto del movimiento-(p_concepto)
                             v_nro_secuencia,                            --Nro. de secuencia-(p_nro_secuencia)
                             v_hora,                                     --hora -(p_hora)
                             v_mto_cuota,                         --monto-(p_monto)
                             null,                                       --estado de la cuenta si corresponde-(p_est_cuenta)
                             Null,                                       --referencia si corresponde-(p_referencia)
                             v_cod_sit_contable,                         --Cód. Situacion contable-(p_cod_sit_contable)
                             null);
         End if;
             --------------------------------------------------------------
              -- Si la cancelación es Automática, insertamos la transaccion de Pago de la Operacion(741) --
              If nvl(v_can_automatica,'N') = 'S' Then
                  -- Insertamos el movimiento por la Cancelacion del Repo --
                  v_mensaje := 'Inserta Compra Repo Cancelado - CV.';
                  pp_ins_com_documentos (r_pcta.nro_cuenta,   -- Cuenta del instrumento
                                         nvl(r_pcta.monto,0), -- Valor del Repo
                                         v_nro_secuencia,
                                         v_hora);
              End If;

         End If;
          PAM_DOC.PR_ACT_OPE_REPO (r_pcta.nro_cuenta,    ---Nro. Cta. correspondiente al REPO
                                      'CD',                 ---Este valor corresponde a la acción que en este caso es Cancelación de REPO.
                                      v_nro_secuencia,    ---Nro. de secuencia utilizado para insertar datos en ge_movimientos
                                      v_hora);
         
      --******************************************************--
           ---> Cancelación de Instrumentos realcionados a REPO RECIBIDO
      --******************************************************--
       Elsif p_accion = 'CD' then
         --------------------------------------------------------------
         -- Si el Repo aun no fue cancelado, lo cancelamos automaticamente --
         If r_pcta.estado =  'E' Then
             v_can_automatica := 'S';
             PAM_DOC.PR_ACT_OPE_REPO (r_pcta.nro_cuenta,    ---Nro. Cta. correspondiente al REPO
                                      'CV',                 ---Este valor corresponde a la acción que en este caso es Cancelación de REPO.
                                      v_nro_secuencia,    ---Nro. de secuencia utilizado para insertar datos en ge_movimientos
                                      v_hora);            ---Hora utilizado para insertar datos en ge_movimientos
         End If;
         
         begin
            select i.estado
             into v_est_det_bono
            from md_cuo_instrumentos i
            where i.nro_cta_repo = r_pcta.nro_cuenta;
          Exception
           When Others Then
             v_est_det_bono := null;
         end;
         
         if v_est_det_bono <> 'N' then
         -- Actualiza los Instrumentos de Negociacion Repo ---
         v_mensaje := 'Actualiza Doc. Relacionado - CD.';
         pp_act_doc_relacionados(r_pcta.nro_cuenta,                --Se envia el nro. de Cuenta REPO - (p_cta_principal)
                                 Null,                             --(OBS: se actualiza en pp_act_cuenta) Estado al que se deberá actualizar la Cuenta REPO: N-Cancelado-(p_estado)
                                 'C',                              --Estado para las Ctas. de Documentos Relac (md_cta_documentos)- C-Vigente - (p_est_cta_relacionada)
                                 Null,                             --(OBS: tabla sin estado) Estado al que se deberá actualizar (md_operaciones_det): N-Cancelado-(p_est_ope_det)
                                 'N',                              --Estado al que se deberá la Cuota de cada documento (md_cuo_instrumentos): C - Vigente - (p_est_doc_cuota)
                                 v_nro_secuencia,                  --Número de Secuencia para Inserción de Movimientos-(p_nro_secuencia)
                                 v_hora);                          --Hora para Inserción de Movimientos - (p_hora)

         --- Asignamos el cod_sit_contable para los movimientos --
         --- Debido a la configuración contable para la Re-clasificacion de documentos en REPO --
         v_cod_sit_contable := Null;
         v_cod_sit_contable := 10000003;
         -----------------------------------------------------------------------------
         -- Cursor de instrumentos relacionados --
         for c_ins in c_intrumentos Loop
              -- Hallamos el porcentaje de la cuota con respecto al monto del intrumento --
             -- v_por_cuota := nvl((nvl(c_ins.mto_cuota,0) * 100) / nvl(c_ins.monto,0),0);
              --------------------------------------------------------------
              If nvl(c_ins.mto_cuota,0) > 0 Then
                --Valor de la Venta del documento - inserta val_presente de la Venta del Doc.
                v_mto_int_cuota := nvl(c_ins.mto_cuota,0);----NVL((nvl(c_ins.int_documento,0) * v_por_cuota) / 100,0);
                --  Venta Documento - 806
                 v_mensaje := 'Baja de garantia 806 - CD.';
                 pp_ins_movimiento(c_ins.nro_cuenta,                                  --Nro. Cta. del Instrumento-(p_nro_rel_repo)
                                   null,                                              --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   101,                                               --Cód. trans Padre  -(p_cod_tra_padre)
                                   806,                                               --Cód. trans hijo-(p_cod_transaccion)
                                   'Baja de garantia '||c_ins.nro_cuenta,                  --Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                                   --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                            --hora -(p_hora)
                                   v_mto_int_cuota,/*(nvl(c_ins.mto_cuota,0) - v_mto_int_cuota),*/        --monto-(p_monto)
                                   null,                                              --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                              --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                               --Cód. Situacion contable-(p_cod_sit_contable)
                                   null);
              End If;
              --------------------------------------------------------------
              /*If nvl(c_ins.int_repo,0) > 0 Then
               -- Hallamos el monto de acuerdo al porcentaje de valor de cuota
                 --v_mto_int_cuota := NVL((nvl(c_ins.int_documento,0) * v_por_cuota) / 100,0);

               --  Venta Documento - 814 - Afecta Interes
                 v_mensaje := 'Inserta Venta Documento 814 - CD.';
                 pp_ins_movimiento(c_ins.nro_cuenta,                               --Nro. Cta. del Instrumento-(p_nro_rel_repo)
                                   null,                                           --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   101,                                            --Cód. trans Padre  -(p_cod_tra_padre)
                                   814,                                            --Cód. trans hijo-(p_cod_transaccion)
                                   'Compra REPO - Intere Instrumento '||c_ins.nro_cuenta,               --Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                                --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                         --hora -(p_hora)
                                   c_ins.int_repo,                                --monto-(p_monto)
                                   null,                                           --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                           --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                             --Cód. Situacion contable-(p_cod_sit_contable)
                                   null);
              End If;*/
              --------------------------------------------------------------
              --  Compra REPO - 802 / Generar movimiento Interés no Devengado
              /*If nvl(c_ins.val_int_devengar,0) > 0 Then
                 -- Hallamos el monto de acuerdo al porcentaje de valor de cuota
                 --v_val_int_dev_cuota := NVL((nvl(c_ins.val_int_devengar,0) * v_por_cuota) / 100,0);

                 -- Hallamos el monto de Interes a Devengar al alta de Reclasificacion del instrumento --
                 Begin
                   Select nvl(ci.val_int_cuo_devengar,0), nvl(ci.mto_dev_cuo_actual,0)
                     Into v_val_int_dev_cuota, v_val_int_dev_dia_cuota
                     From md_cuo_instrumentos ci
                    Where ci.nro_cuenta   = c_ins.nro_cuenta
                      And ci.nro_cuota    = c_ins.nro_cuota
                      And ci.nro_cta_repo = c_ins.nro_cta_repo;
                 Exception
                   When Others Then
                     v_val_int_dev_cuota := 0;
                     v_val_int_dev_dia_cuota := 0;
                 End;

                 v_mensaje := 'Inserta Devengado Documento 802 - CD.';
                 -- Traslado de devengado total en la Reclasificacion --
                 pp_ins_movimiento(c_ins.nro_cuenta,                         --Nro. Cta. Instrumento-(p_nro_rel_repo)
                                   null,                                     --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   101,                                      --Cód. trans Padre  -(p_cod_tra_padre)
                                   802,                                      --Cód. trans hijo-(p_cod_transaccion)
                                   'Compra REPO - Interes Deven. '||c_ins.nro_cuenta,  --Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                          --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                   --hora -(p_hora)
                                   v_val_int_dev_cuota,                      --monto-(p_monto)
                                   null,                                     --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                     --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                       --Cód. Situacion contable-(p_cod_sit_contable)
                                   null);

                 -- Cancelacion de devengado diario durante la Reclasificacion --
                 pp_ins_movimiento(c_ins.nro_cuenta,                                      --Nro. Cta. Instrumento-(p_nro_rel_repo)
                                   null,                                                  --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   101,                                                   --Cód. trans Padre  -(p_cod_tra_padre)
                                   813,                                                   --Cód. trans hijo-(p_cod_transaccion)
                                   'Compra REPO - Interes Deven. Dia '||c_ins.nro_cuenta, --Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                                       --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                                --hora -(p_hora)
                                   v_val_int_dev_dia_cuota,                               --monto-(p_monto)
                                   null,                                                  --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                                  --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                                    --Cód. Situacion contable-(p_cod_sit_contable)
                                   null);
              End If;*/
           End Loop;
         End If;
        End If;
    End if;
    -----------------------------------------------------------------------------------------

          ---> Modalidad: REPO OTORGADO <---

    -----------------------------------------------------------------------------------------
    --Elsif r_pcta.cod_modalidad = 128 Then
    If FUM_OBT_OPE_REPO(r_pcta.cod_modulo,r_pcta.cod_modalidad,'S','O') = 'S' Then

      v_cod_sit_contable := Null;
      --******************************************************--
           ---> Confirmación REPO OTORGADO
      --******************************************************--
      If p_accion = 'CO' then
         -- Actualizamos la Cuenta Repo --
         v_mensaje := 'Actualiza Cta - CO.';
         pp_act_cuenta(r_pcta.nro_cuenta,                         --Se envia el nro. de Cuenta REPO
                       'C',                                       --Estado al que se deberá actualizar la Cuenta REPO Otorgado: C Vigente --E-Repo
                       v_nro_secuencia,                           --Número de Secuencia para Inserción de Movimientos
                       v_hora);                                   --Hora para Inserción de Movimientos

         -----------------------------------------------------
         ---Movimiento por la confirmación de REPO Otorgado ----
         -----------------------------------------------------
         v_cod_sit_contable := pab_asi.fu_cal_sit_contable(r_pcta.nro_cuenta);
         ---> 1 - Cambio de Estado (ya realiza en pp_act_cuenta)
         ---> 2 - Compra de Documento - Repo Otorgado
         If nvl(r_pcta.monto,0) > 0 Then

           v_mensaje := 'Inserta Mov - Monto - CO.';
           pp_ins_movimiento(r_pcta.nro_cuenta,                                         --Nro. Cta. del REPO-(p_nro_rel_repo)
                             null,                                                      --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_cta_debcre)
                             101,                                                       --Cód. trans Padre-(p_cod_tra_padre)
                             711,                                                       --Cód. trans hijo-(p_cod_transaccion)
                             'REPO Interbancario Otorgado - Capital '||r_pcta.nro_cuenta,   --Concepto del movimiento-(p_concepto)
                             v_nro_secuencia,                                           --Nro. de secuencia-(p_nro_secuencia)
                             v_hora,                                                    --hora -(p_hora)
                             r_pcta.monto - r_pcta.mto_interes,                         --monto -(p_monto)
                             null,                                                      --estado de la cuenta si corresponde-(p_est_cuenta)
                             Null,                                                      --referencia si corresponde-(p_referencia)
                             v_cod_sit_contable,                                        --Cód. Situacion contable-(p_cod_sit_contable)
                             null);
         End if;

         ---> 3 - Compra de Documento - Repo Otorgado
         If nvl(r_pcta.mto_interes,0) > 0 Then

           v_mensaje := 'Inserta Mov - Interes - CO.';
           pp_ins_movimiento(r_pcta.nro_cuenta,                                         --Nro. Cta. del REPO-(p_nro_rel_repo)
                             null,                                                      --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                             101,                                                       --Cód. trans Padre  -(p_cod_tra_padre)
                             719,                                                       --Cód. trans hijo-(p_cod_transaccion)
                             'REPO Interbancario Otorgado - Interes '||r_pcta.nro_cuenta,--Concepto del movimiento-(p_concepto)
                             v_nro_secuencia,                                           --Nro. de secuencia-(p_nro_secuencia)
                             v_hora,                                                    --hora -(p_hora)
                             r_pcta.mto_interes,                                        --monto-(p_monto)
                             null,                                                      --estado de la cuenta si corresponde-(p_est_cuenta)
                             Null,                                                      --referencia si corresponde-(p_referencia)
                             v_cod_sit_contable,                                        --Cód. Situacion contable-(p_cod_sit_contable);
                             null);

         End if;

         ---> 4 - Alta del Titulo - Repo Otorgado
         If nvl(r_pcta.monto,0) > 0 Then

           v_mensaje := 'Inserta Mov - Capital Alta Titulo - CO.';
           pp_ins_movimiento(r_pcta.nro_cuenta,                                   --Nro. Cta. del REPO-(p_nro_rel_repo)
                             null,                                                --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_cta_debcre)
                             101,                                                 --Cód. trans Padre-(p_cod_tra_padre)
                             814,                                                 --Cód. trans hijo-(p_cod_transaccion)
                             'Alta Titulo - REPO Otorgado '||r_pcta.nro_cuenta,   --Concepto del movimiento-(p_concepto)
                             v_nro_secuencia,                                     --Nro. de secuencia-(p_nro_secuencia)
                             v_hora,                                              --hora -(p_hora)
                             r_pcta.monto,                                        --monto -(p_monto)
                             null,                                                --estado de la cuenta si corresponde-(p_est_cuenta)
                             Null,                                                --referencia si corresponde-(p_referencia)
                             v_cod_sit_contable,                                  --Cód. Situacion contable-(p_cod_sit_contable)
                             null);
         End if;

      -----------------------------------------------------------------------------------------
      --******************************************************--
           ---> Cancelación REPO OTORGADO
      --******************************************************--
      Elsif p_accion = 'CC' then
               -- Actualizamos la Cuenta Repo --
               v_mensaje := 'Actualiza Cta - CC.';
               pp_act_cuenta(r_pcta.nro_cuenta,                     --Se envia el nro. de Cuenta REPO - (p_nro_cuenta)
                             'N',                                  --Estado al que se deberá actualizar la Cuenta REPO: N-Cancelado-(p_estado)
                             v_nro_secuencia,                      --Número de Secuencia para Inserción de Movimientos-(p_nro_secuencia)
                             v_hora);                              --Hora para Inserción de Movimientos - (p_hora)

              --------------------------------------------------------------
              --- Asignamos el cod_sit_contable para los movimientos --
              v_cod_sit_contable := Null;
              v_cod_sit_contable := pab_asi.fu_cal_sit_contable(r_pcta.nro_cuenta);

               -- Generamos los movimientos correspondientes --
              If nvl(r_pcta.monto,0)-nvl(r_pcta.mto_interes,0) > 0 Then
                 --Valor de la Re-Venta del documento -
                 --  Re-Venta Documento - 805
                 v_mensaje := 'Inserta Re-Venta Documento 805 - CC.';
                 pp_ins_movimiento(r_pcta.nro_cuenta,                                   --Nro. Cta. del Instrumento-(p_nro_rel_repo)
                                   null,                                                --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   102,                                                 --Cód. trans Padre  -(p_cod_tra_padre)
                                   805,                                                 --Cód. trans hijo-(p_cod_transaccion)
                                   'Re-Venta Documento - Capital '||r_pcta.nro_cuenta,  --Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                                     --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                              --hora -(p_hora)
                                   nvl(r_pcta.monto,0)-nvl(r_pcta.mto_interes,0),       --monto-(p_monto)
                                   null,                                                --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                                --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                                  --Cód. Situacion contable-(p_cod_sit_contable);
                                   null);
              End If;
              --------------------------------------------------------------
              If nvl(r_pcta.mto_interes,0) > 0 Then
               --  Re-Venta Documento - 817 - Afecta Interes
                 v_mensaje := 'Inserta Re-Venta Documento 817 - CC.';
                 pp_ins_movimiento(r_pcta.nro_cuenta,                                  --Nro. Cta. del Instrumento-(p_nro_rel_repo)
                                   null,                                               --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                   102,                                                --Cód. trans Padre  -(p_cod_tra_padre)
                                   817,                                                --Cód. trans hijo-(p_cod_transaccion)
                                   'Re-Venta Documento - Interes '||r_pcta.nro_cuenta, --Concepto del movimiento-(p_concepto)
                                   v_nro_secuencia,                                    --Nro. de secuencia-(p_nro_secuencia)
                                   v_hora,                                             --hora -(p_hora)
                                   nvl(r_pcta.mto_interes,0),                          --monto-(p_monto)
                                   null,                                               --estado de la cuenta si corresponde-(p_est_cuenta)
                                   Null,                                               --referencia si corresponde-(p_referencia)
                                   v_cod_sit_contable,                                 --Cód. Situacion contable-(p_cod_sit_contable);
                                   null);

                -- Indicador Tipo de Persona: P-Bancos del País, B-BCP, C-Clientes --
                v_mensaje := 'Indica Tipo Persona para Sector Contable.';
                begin
                  select o.tip_persona
                    into v_tip_persona
                    from md_tip_operaciones o
                   where o.cod_mad_operacion = r_pcta.cod_modalidad;
                exception
                  when others then
                    raise_application_error(-20000, v_mensaje || ' ' || 'error:' || v_error);
                end;

                -- Si la persona es distinta a BCP, debemos generar el iva por el interes --
                if v_tip_persona <> 'B' then
                  --  Re-Venta Documento - 518 - IVA sobre Interes
                  v_mto_iva_interes := NVL((nvl(r_pcta.mto_interes,0) * v_val_por_iva) / 100,0);
                  v_mensaje := 'Inserta IVA Re-Venta Documento 581 - CC.';
                  pp_ins_movimiento(r_pcta.nro_cuenta,                                     --Nro. Cta. del Instrumento-(p_nro_rel_repo)
                                    null,                                                  --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_rel_repo)
                                    102,                                                   --Cód. trans Padre  -(p_cod_tra_padre)
                                    518,                                                   --Cód. trans hijo-(p_cod_transaccion)
                                    'Re-Venta Documento - IVA Interes '||r_pcta.nro_cuenta,--Concepto del movimiento-(p_concepto)
                                    v_nro_secuencia,                                       --Nro. de secuencia-(p_nro_secuencia)
                                    v_hora,                                                --hora -(p_hora)
                                    nvl(v_mto_iva_interes,0),                             --monto-(p_monto)
                                    null,                                                  --estado de la cuenta si corresponde-(p_est_cuenta)
                                    Null,                                                  --referencia si corresponde-(p_referencia)
                                    v_cod_sit_contable,
                                    v_val_por_iva);
                end if;
              End If;

              ---> - Baja del Titulo - Repo Otorgado - CNFREINT-104
              If nvl(r_pcta.monto,0) > 0 Then
                --- Debido a la configuración contable para la Baja del Titulo en REPO Otorgado --
                v_cod_sit_contable := Null;
                v_cod_sit_contable := 10000000;

                v_mensaje := 'Inserta Mov - Baja Titulo - CO.';
                pp_ins_movimiento(r_pcta.nro_cuenta,                    --Nro. Cta. del REPO-(p_nro_rel_repo)
                                  null,                                 --Nro. Cta. Débito / Crédito (solo modulos 3 y 4)-(p_nro_cta_debcre)
                                  102,                                  --Cód. trans Padre-(p_cod_tra_padre)
                                  814,                                  --Cód. trans hijo-(p_cod_transaccion)
                                  'Baja Titulo - REPO Otorgado',        --Concepto del movimiento-(p_concepto)
                                  v_nro_secuencia,                      --Nro. de secuencia-(p_nro_secuencia)
                                  v_hora,                               --hora -(p_hora)
                                  r_pcta.monto,                         --monto -(p_monto)
                                  null,                                 --estado de la cuenta si corresponde-(p_est_cuenta)
                                  null,                                 --referencia si corresponde-(p_referencia)
                                  v_cod_sit_contable,                   --Cód. Situacion contable-(p_cod_sit_contable)
                                  null);
              End if;
       End If;
    End If;

    P_HORA           := v_hora;
    P_NRO_SECUENCIA  := v_nro_secuencia;


    ---------------------------------------------------------
                -- FIN - PROCESO PRINCIPAL --
    ---------------------------------------------------------

exception
  when others Then
     v_error := Sqlerrm;
     raise_application_error(-20005, 'Actualización Operacion REPO: '||P_NRO_CUENTA||'. '||v_mensaje||'. '||v_error);

END PR_ACT_OPE_REPO;

  /* Pago automatico AFD — consumido por sf-job-processor (job AFD_PAYMENT).
     Orquesta pr_pag_operacion + movimiento 741 (SIPAP). */
  PROCEDURE PR_PAG_OPERACION_AFD_AUTO (
    P_NRO_CUENTA       IN  MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE,
    P_COD_RUBRO_SIPAP  IN  CB_RUBROS.COD_RUBRO%TYPE,
    P_NRO_CUOTA        IN  NUMBER,
    P_COD_RESPUESTA    OUT VARCHAR2,
    P_MSJ_RESPUESTA    OUT VARCHAR2
  ) IS
    c_cod_resp_ok               CONSTANT VARCHAR2(3) := '000';
    c_err_cuenta_obligatoria    CONSTANT VARCHAR2(3) := '101';
    c_err_rubro_sipap           CONSTANT VARCHAR2(3) := '102';
    c_err_modalidad_invalida    CONSTANT VARCHAR2(3) := '103';
    c_err_tip_operacion         CONSTANT VARCHAR2(3) := '104';
    c_err_estado_operacion      CONSTANT VARCHAR2(3) := '105';
    c_err_operacion_repo        CONSTANT VARCHAR2(3) := '106';
    c_err_sin_cuotas_vencidas   CONSTANT VARCHAR2(3) := '107';
    c_err_cuota_hasta_invalida  CONSTANT VARCHAR2(3) := '108';
    c_err_moneda_no_registrada  CONSTANT VARCHAR2(3) := '109';
    c_err_persona_no_registrada CONSTANT VARCHAR2(3) := '110';
    c_err_sin_saldo_cuotas      CONSTANT VARCHAR2(3) := '111';
    c_err_monto_invalido        CONSTANT VARCHAR2(3) := '112';
    c_err_generico              CONSTANT VARCHAR2(3) := '999';
    c_mod_prestamos             CONSTANT NUMBER := 10;

    r_docu               md_cta_documentos%ROWTYPE;

    v_chk                NUMBER;

    v_wk_fcdehoy         DATE;
    v_nro_cuo_desde      NUMBER;
    v_max_nro_cuota      NUMBER;
    v_cnt_cuotas_saldo   NUMBER;

    v_mto_capital  NUMBER := 0;
    v_mto_interes  NUMBER := 0;
    v_mto_impuesto NUMBER := 0;
    v_mto_a_pagar  NUMBER := 0;

    v_hora               ge_movimientos.hora%TYPE;
    v_nro_secuencia      ge_movimientos.nro_secuencia%TYPE;
    v_cotizacion         ge_movimientos.cotizacion%TYPE;
    v_cod_rubro          cb_rubros.cod_rubro%TYPE;
    v_cod_moneda_rubro   cb_rubros.cod_moneda%TYPE;
    v_wk_cdofici         ge_movimientos.cod_oficina%TYPE;

    PROCEDURE p_set_error(p_cod IN VARCHAR2, p_mensaje IN VARCHAR2) IS
    BEGIN
      P_COD_RESPUESTA := p_cod;
      P_MSJ_RESPUESTA := SUBSTR(p_mensaje, 1, 4000);
    END p_set_error;

    FUNCTION f_es_error RETURN BOOLEAN IS
    BEGIN
      RETURN P_COD_RESPUESTA IS NOT NULL AND P_COD_RESPUESTA <> c_cod_resp_ok;
    END f_es_error;

    PROCEDURE p_calcular_montos (
      p_nro_cuota    IN  NUMBER,
      p_mto_capital  OUT NUMBER,
      p_mto_interes  OUT NUMBER,
      p_mto_impuesto OUT NUMBER,
      p_mto_a_pagar  OUT NUMBER
    ) IS
    BEGIN
      p_mto_capital  := 0;
      p_mto_interes  := 0;
      p_mto_impuesto := 0;

      BEGIN
        SELECT NVL(dd.sal_capital, 0),
               NVL(dd.sal_interes, 0),
               NVL(dd.mto_impuesto, 0)
          INTO p_mto_capital,
               p_mto_interes,
               p_mto_impuesto
          FROM md_doc_detalles dd
         WHERE dd.nro_cuenta = P_NRO_CUENTA
           AND dd.estado <> 'N'
           AND dd.nro_cuota = p_nro_cuota;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
      END;

      p_mto_a_pagar := p_mto_capital + p_mto_interes + p_mto_impuesto;

      IF p_mto_a_pagar <= 0 THEN
        p_set_error(c_err_monto_invalido,
          'Cuenta ' || P_NRO_CUENTA || ': monto a pagar es cero o negativo.');
      END IF;
    END p_calcular_montos;

    PROCEDURE p_pp_dat_contable (
      p_cod_rubro        IN cb_rubros.cod_rubro%TYPE,
      p_docu             IN md_cta_documentos%ROWTYPE,
      p_cod_moneda_rubro OUT cb_rubros.cod_moneda%TYPE
    ) IS
    BEGIN
      BEGIN
        SELECT cr.cod_moneda
          INTO p_cod_moneda_rubro
          FROM cb_rubros cr
         WHERE cr.cod_rubro = p_cod_rubro
           AND cr.imputable = 'S';
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          p_set_error(c_err_rubro_sipap,
            'Cuenta ' || P_NRO_CUENTA
            || ': rubro ' || p_cod_rubro || ' no registrado o no imputable.');
          RETURN;
      END;

      IF p_cod_moneda_rubro <> p_docu.cod_moneda THEN
        p_set_error(c_err_rubro_sipap,
          'Cuenta ' || P_NRO_CUENTA
          || ': moneda del rubro (' || p_cod_moneda_rubro
          || ') distinta a moneda de la operación (' || p_docu.cod_moneda || ').');
      END IF;
    END p_pp_dat_contable;

    PROCEDURE p_insertar_movimiento_741 (
      p_nro_cuenta       IN md_cta_documentos.nro_cuenta%TYPE,
      p_hora             IN ge_movimientos.hora%TYPE,
      p_fecha            IN ge_movimientos.fecha%TYPE,
      p_cotizacion       IN ge_movimientos.cotizacion%TYPE,
      p_monto            IN NUMBER,
      p_cod_rubro        IN cb_rubros.cod_rubro%TYPE,
      p_cod_moneda_rubro IN cb_rubros.cod_moneda%TYPE,
      p_cod_oficina      IN ge_movimientos.cod_oficina%TYPE,
      p_docu             IN md_cta_documentos%ROWTYPE,
      p_nro_secuencia    IN OUT ge_movimientos.nro_secuencia%TYPE
    ) IS
      r_gmovi ge_movimientos%ROWTYPE;
    BEGIN
      r_gmovi.cod_usuario     := USER;
      r_gmovi.hora            := p_hora;
      r_gmovi.fecha           := p_fecha;
      p_nro_secuencia         := p_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := p_nro_secuencia;
      r_gmovi.cod_modulo      := p_docu.cod_modulo;
      r_gmovi.cod_modalidad   := p_docu.cod_modalidad;
      r_gmovi.cod_oficina     := p_cod_oficina;
      r_gmovi.cod_moneda      := p_cod_moneda_rubro;
      r_gmovi.fec_valor       := p_fecha;
      r_gmovi.cod_tra_padre   := 360;
      r_gmovi.cod_mod_padre   := p_docu.cod_modulo;
      r_gmovi.cod_mad_padre   := p_docu.cod_modalidad;
      r_gmovi.cod_transaccion := 741;
      r_gmovi.monto           := p_monto;
      r_gmovi.nro_documento   := p_nro_cuenta;
      r_gmovi.cod_ofi_origen  := p_docu.cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Pago de Operac. ' || p_nro_cuenta;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_rubro       := p_cod_rubro;
      r_gmovi.nro_cuenta      := NULL;
      r_gmovi.tip_mov_rubro   := 'C';
      r_gmovi.cotizacion      := p_cotizacion;
      r_gmovi.mto_equ_local   := ROUND(r_gmovi.monto * p_cotizacion, 0);

      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END p_insertar_movimiento_741;

  BEGIN
    P_COD_RESPUESTA := c_cod_resp_ok;
    P_MSJ_RESPUESTA := NULL;

    IF P_NRO_CUENTA IS NULL THEN
      p_set_error(c_err_cuenta_obligatoria, 'Número de cuenta es obligatorio.');
      RETURN;
    END IF;

    IF P_COD_RUBRO_SIPAP IS NULL OR TRIM(P_COD_RUBRO_SIPAP) IS NULL THEN
      p_set_error(c_err_rubro_sipap, 'Código de rubro SIPAP es obligatorio.');
      RETURN;
    END IF;
    v_cod_rubro := TRIM(P_COD_RUBRO_SIPAP);
    
    IF P_NRO_CUOTA IS NULL OR P_NRO_CUOTA <= 0 THEN
      p_set_error(c_err_cuota_hasta_invalida,
        'Cuenta ' || P_NRO_CUENTA || ': número de cuota inválido.');
      RETURN;
    END IF;

    pr_obt_datos(P_NRO_CUENTA, r_docu);

    IF r_docu.cod_modulo <> c_mod_prestamos THEN
      p_set_error(c_err_modalidad_invalida,
        'Cuenta ' || P_NRO_CUENTA || ': diferente a módulo 10.');
      RETURN;
    END IF;

    IF fu_obt_tip_operacion(P_NRO_CUENTA) <> 'P' THEN
      p_set_error(c_err_tip_operacion,
        'Cuenta ' || P_NRO_CUENTA || ': no es operación pasiva (tip_operacion <> P).');
      RETURN;
    END IF;

    IF r_docu.estado NOT IN ('C', 'E') THEN
      p_set_error(c_err_estado_operacion,
        'Cuenta ' || P_NRO_CUENTA || ': la operación debe estar activa (C/E).');
      RETURN;
    END IF;

    IF fum_obt_ope_repo(r_docu.cod_modulo, r_docu.cod_modalidad, 'S') <> 'N' THEN
      p_set_error(c_err_operacion_repo,
        'Cuenta ' || P_NRO_CUENTA || ': operación REPO; no aplica pago AFD estándar.');
      RETURN;
    END IF;

    v_wk_fcdehoy := pae_cnf.fu_obt_fec_actual(r_docu.cod_modulo);

    v_nro_cuo_desde := fu_obt_min_cuo_vencida(P_NRO_CUENTA, v_wk_fcdehoy);

    IF v_nro_cuo_desde IS NULL THEN
      p_set_error(c_err_sin_cuotas_vencidas,
        'Cuenta ' || P_NRO_CUENTA || ': no tiene cuotas pendientes');
      RETURN;
    END IF;

    IF P_NRO_CUOTA <> v_nro_cuo_desde THEN
      p_set_error(c_err_cuota_hasta_invalida,
        'Cuenta ' || P_NRO_CUENTA || ': la cuota a pagar debe ser la mínima pendiente ('
        || v_nro_cuo_desde || ').');
      RETURN;
    END IF;

    IF P_NRO_CUOTA IS NOT NULL THEN
      SELECT MAX(dd.nro_cuota)
        INTO v_max_nro_cuota
        FROM md_doc_detalles dd
       WHERE dd.nro_cuenta = P_NRO_CUENTA
         AND dd.nro_cuota > 0
         AND dd.estado <> 'N';

      IF P_NRO_CUOTA > NVL(v_max_nro_cuota, 0) THEN
        p_set_error(c_err_cuota_hasta_invalida,
          'Cuenta ' || P_NRO_CUENTA || ': cuota no puede ser mayor a la cuota '
          || NVL(TO_CHAR(v_max_nro_cuota), '0') || '.');
        RETURN;
      ELSIF v_max_nro_cuota IS NULL THEN
        p_set_error(c_err_sin_cuotas_vencidas,
          'Cuenta ' || P_NRO_CUENTA || ': la operación no posee cuotas pendientes.');
        RETURN;
      END IF;
    END IF;
    
    BEGIN
      SELECT 1
        INTO v_chk
        FROM ba_monedas
       WHERE cod_moneda = r_docu.cod_moneda
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        p_set_error(c_err_moneda_no_registrada,
          'Cuenta ' || P_NRO_CUENTA || ': moneda no registrada.');
        RETURN;
    END;

    BEGIN
      SELECT 1
        INTO v_chk
        FROM ba_personas p
       WHERE p.cod_persona = r_docu.cod_persona
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        p_set_error(c_err_persona_no_registrada,
          'Cuenta ' || P_NRO_CUENTA || ': persona no registrada.');
        RETURN;
    END;

    SELECT COUNT(*)
      INTO v_cnt_cuotas_saldo
      FROM md_doc_detalles dd
     WHERE dd.nro_cuenta = P_NRO_CUENTA
       AND dd.estado NOT IN ('N', 'I')
       AND dd.nro_cuota = P_NRO_CUOTA
       AND NVL(dd.sal_capital, 0) + NVL(dd.sal_interes, 0) > 0;

    IF v_cnt_cuotas_saldo = 0 THEN
      p_set_error(c_err_sin_saldo_cuotas,
        'Cuenta ' || P_NRO_CUENTA
        || ': sin saldo pendiente en cuota ' || P_NRO_CUOTA);
      RETURN;
    END IF;

    p_calcular_montos(
      p_nro_cuota    => P_NRO_CUOTA,
      p_mto_capital  => v_mto_capital,
      p_mto_interes  => v_mto_interes,
      p_mto_impuesto => v_mto_impuesto,
      p_mto_a_pagar  => v_mto_a_pagar
    );
    IF f_es_error THEN
      RETURN;
    END IF;

    p_pp_dat_contable(
      p_cod_rubro        => v_cod_rubro,
      p_docu             => r_docu,
      p_cod_moneda_rubro => v_cod_moneda_rubro
    );
    IF f_es_error THEN
      RETURN;
    END IF;

    v_wk_cdofici := r_docu.cod_oficina;

    v_hora          := TO_CHAR(SYSDATE, 'hh24:mi:ss');
    v_nro_secuencia := 0;
    v_cotizacion    := NULL;

    IF v_cod_moneda_rubro <> pag_gen.fu_obt_mon_local THEN
      v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda_rubro, v_wk_fcdehoy);
    END IF;

    pr_pag_operacion(
      p_nro_cuenta         => P_NRO_CUENTA,
      p_nro_cuo_desde      => P_NRO_CUOTA,
      p_nro_cuo_hasta      => P_NRO_CUOTA,
      p_mto_a_pagar        => v_mto_a_pagar,
      p_mto_capital        => v_mto_capital,
      p_mto_interes        => v_mto_interes,
      p_mto_int_descontado => 0,
      p_mto_int_moratorio  => 0,
      p_mto_impuesto       => v_mto_impuesto,
      p_mto_cargo          => 0,
      p_mto_garantia       => 0,
      p_cod_ofi_origen     => r_docu.cod_oficina,
      p_fecha              => v_wk_fcdehoy,
      p_hora               => v_hora,
      p_nro_secuencia      => v_nro_secuencia
    );

    p_insertar_movimiento_741(
      p_nro_cuenta       => P_NRO_CUENTA,
      p_hora             => v_hora,
      p_fecha            => v_wk_fcdehoy,
      p_cotizacion       => v_cotizacion,
      p_monto            => v_mto_a_pagar,
      p_cod_rubro        => v_cod_rubro,
      p_cod_moneda_rubro => v_cod_moneda_rubro,
      p_cod_oficina      => v_wk_cdofici,
      p_docu             => r_docu,
      p_nro_secuencia    => v_nro_secuencia
    );

    P_COD_RESPUESTA := c_cod_resp_ok;
    P_MSJ_RESPUESTA := 'OK cuenta ' || P_NRO_CUENTA
      || ' cuota ' || P_NRO_CUOTA
      || ' monto ' || v_mto_a_pagar;

  EXCEPTION
    WHEN OTHERS THEN
      p_set_error(c_err_generico, 'Cuenta ' || P_NRO_CUENTA || ': ' || SQLERRM);
  END PR_PAG_OPERACION_AFD_AUTO;

  FUNCTION fu_suma_fli_vigente(p_nro_cuenta    IN md_cta_documentos.nro_cuenta%TYPE,
                               p_nro_documento IN md_cta_documentos.nro_documento%TYPE DEFAULT NULL)
    RETURN NUMBER IS
    v_fli NUMBER;
  BEGIN
    SELECT NVL(SUM(f.monto), 0)
      INTO v_fli
      FROM sb_snp_fli f
     WHERE f.nro_cuenta = p_nro_cuenta
       AND f.situacion = 'V'
       AND (p_nro_documento IS NULL OR f.nro_documento = p_nro_documento);
    RETURN v_fli;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END fu_suma_fli_vigente;

  FUNCTION fu_calc_disp(p_nro_cuenta IN md_cta_documentos.nro_cuenta%TYPE) RETURN NUMBER IS
    v_monto NUMBER;
    v_rest  NUMBER;
  BEGIN
    SELECT d.monto, NVL(d.sal_restringido, 0)
      INTO v_monto, v_rest
      FROM md_cta_documentos d
     WHERE d.nro_cuenta = p_nro_cuenta;
    RETURN v_monto - v_rest - fu_suma_fli_vigente(p_nro_cuenta);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END fu_calc_disp;

  --- sal_restringido ≤ monto
  FUNCTION fu_ok_rest_vs_monto(p_nro_cuenta IN md_cta_documentos.nro_cuenta%TYPE) RETURN VARCHAR2 IS
    v_monto NUMBER;
    v_rest  NUMBER;
  BEGIN
    SELECT d.monto, NVL(d.sal_restringido, 0)
      INTO v_monto, v_rest
      FROM md_cta_documentos d
     WHERE d.nro_cuenta = p_nro_cuenta;
    IF v_rest <= v_monto THEN
      RETURN 'S';
    END IF;
    RETURN 'N';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'N';
  END fu_ok_rest_vs_monto;

  --- rest + FLI vigente + deltas ≤ monto
  FUNCTION fu_ok_rest_fli_vs_monto_proy(p_nro_cuenta  IN md_cta_documentos.nro_cuenta%TYPE,
                                        p_delta_rest  IN NUMBER DEFAULT 0,
                                        p_delta_fli   IN NUMBER DEFAULT 0) RETURN BOOLEAN IS
    v_monto NUMBER;
    v_rest  NUMBER;
    v_fli   NUMBER;
  BEGIN
    SELECT d.monto, NVL(d.sal_restringido, 0)
      INTO v_monto, v_rest
      FROM md_cta_documentos d
     WHERE d.nro_cuenta = p_nro_cuenta;
    v_fli := fu_suma_fli_vigente(p_nro_cuenta);
    RETURN (v_rest + p_delta_rest + v_fli + p_delta_fli) <= v_monto;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
  END fu_ok_rest_fli_vs_monto_proy;

  FUNCTION fu_capacidad_rest_dest(p_nro_cuenta_dest IN md_cta_documentos.nro_cuenta%TYPE)
    RETURN NUMBER IS
    v_monto NUMBER;
    v_rest  NUMBER;
    v_fli   NUMBER;
  BEGIN
    SELECT d.monto, NVL(d.sal_restringido, 0)
      INTO v_monto, v_rest
      FROM md_cta_documentos d
     WHERE d.nro_cuenta = p_nro_cuenta_dest;
    v_fli := fu_suma_fli_vigente(p_nro_cuenta_dest);
    RETURN GREATEST(v_monto - v_rest - v_fli, 0);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END fu_capacidad_rest_dest;

  PROCEDURE pr_set_error_r5(p_cod_error OUT NUMBER,
                            p_des_error OUT VARCHAR2) IS
  BEGIN
    p_cod_error := cg_fli_err_cobertura;
    p_des_error := cg_fli_msg_r5;
  END pr_set_error_r5;

  --- Baja (824) en origen + alta (823) en destino por monto reasignado
  PROCEDURE pr_conta_reasigna_garantia_fli(
    p_nro_cuenta_orig IN  md_cta_documentos.nro_cuenta%TYPE,
    p_nro_cuenta_dest IN  md_cta_documentos.nro_cuenta%TYPE,
    p_monto           IN  NUMBER,
    p_ref_543         IN  sb_snp_fli.nro_ref_externa%TYPE,
    p_cod_error       OUT NUMBER,
    p_des_error       OUT VARCHAR2,
    p_nro_secuencia   IN OUT NUMBER
  ) IS
    v_mod_orig md_cta_documentos.cod_modalidad%TYPE;
    v_mon_orig md_cta_documentos.cod_moneda%TYPE;
    v_mod_dest md_cta_documentos.cod_modalidad%TYPE;
    v_mon_dest md_cta_documentos.cod_moneda%TYPE;
    v_mod_pd   md_cta_documentos.cod_modalidad%TYPE;
    v_fecha    DATE;
    v_hora     ge_movimientos.hora%TYPE;
  BEGIN
    p_cod_error := cg_fli_ok;
    p_des_error := NULL;

    IF NVL(p_monto, 0) <= 0
       OR p_nro_cuenta_orig IS NULL
       OR p_nro_cuenta_dest IS NULL
       OR p_ref_543 IS NULL THEN
      p_cod_error := cg_fli_err_param;
      p_des_error := 'Parametros invalidos para imputacion garantia FLI';
      RETURN;
    END IF;

    SELECT d.cod_modalidad, NVL(d.cod_moneda, 'GS')
      INTO v_mod_orig, v_mon_orig
      FROM md_cta_documentos d
     WHERE d.nro_cuenta = p_nro_cuenta_orig
       AND d.cod_modulo = 10;

    SELECT d.cod_modalidad, NVL(d.cod_moneda, 'GS')
      INTO v_mod_dest, v_mon_dest
      FROM md_cta_documentos d
     WHERE d.nro_cuenta = p_nro_cuenta_dest
       AND d.cod_modulo = 10;

    --- Modalidad producto (cuenta garantizada): nro_documento = RXXXX/543.
    --- Puede haber mas de una cuenta con el mismo nro_documento: tomar la de
    --- fec_insercion mas reciente (1 fila) para cod_mad_padre.
    BEGIN
      SELECT  d.cod_modalidad
        INTO v_mod_pd
        FROM md_cta_documentos d
       WHERE d.nro_documento = p_ref_543
         AND d.estado = 'E'
         AND d.cod_modulo = 10;       
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        p_cod_error := cg_fli_err_param;
        p_des_error := 'Sin cuenta producto para ref_543=' || p_ref_543;
        RETURN;
      WHEN TOO_MANY_ROWS THEN
        p_cod_error := cg_fli_err_param;
        p_des_error := 'Mas de una cuenta en estado E para ref_543=' || p_ref_543;
        RETURN;
    END;

    v_fecha         := pag_cal.fu_obt_fec_actual(10);
    v_hora          := TO_CHAR(SYSDATE, 'HH24:MI:SS');
    p_nro_secuencia := NVL(p_nro_secuencia, 0);

    --- Baja garantia en cuenta origen
    IT.PAM_FRC.PR_INS_MOV_GARANTIA(
      p_nro_cuenta       => TO_CHAR(p_nro_cuenta_orig),
      p_cod_modalidad    => v_mod_orig,
      p_monto            => p_monto,
      p_cod_moneda       => v_mon_orig,
      p_cod_modalidad_pd => v_mod_pd,
      p_es_alta          => 'N',
      p_fecha_movimiento => v_fecha,
      p_hora_movimiento  => v_hora,
      p_nro_secuencia    => p_nro_secuencia
    );
    IF IT.PAM_FRC.FU_OBT_COD_ERROR <> 0 THEN
      p_cod_error := cg_fli_err_conta;
      p_des_error := 'Error baja garantia FLI: '
                     || IT.PAM_FRC.FU_OBT_MSJ_ERROR;
      RETURN;
    END IF;

    --- Alta garantia en cuenta destino
    IT.PAM_FRC.PR_INS_MOV_GARANTIA(
      p_nro_cuenta       => TO_CHAR(p_nro_cuenta_dest),
      p_cod_modalidad    => v_mod_dest,
      p_monto            => p_monto,
      p_cod_moneda       => v_mon_dest,
      p_cod_modalidad_pd => v_mod_pd,
      p_es_alta          => 'S',
      p_fecha_movimiento => v_fecha,
      p_hora_movimiento  => v_hora,
      p_nro_secuencia    => p_nro_secuencia
    );
    IF IT.PAM_FRC.FU_OBT_COD_ERROR <> 0 THEN
      p_cod_error := cg_fli_err_conta;
      p_des_error := 'Error alta garantia FLI: '
                     || IT.PAM_FRC.FU_OBT_MSJ_ERROR;
      RETURN;
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_cod_error := cg_fli_err_param;
      p_des_error := 'Cuenta origen/destino no encontrada para imputacion FLI';
    WHEN OTHERS THEN
      p_cod_error := cg_fli_err_conta;
      p_des_error := 'Error imputacion garantia FLI: '
                     || SUBSTR(SQLERRM, 1, 500);
  END pr_conta_reasigna_garantia_fli;

  --- origen sin rest ni FLI vigente (venta total)
  FUNCTION fu_ok_origen_limpio(p_nro_cuenta    IN md_cta_documentos.nro_cuenta%TYPE,
                               p_nro_documento IN md_cta_documentos.nro_documento%TYPE)
    RETURN BOOLEAN IS
    v_rest NUMBER;
    v_fli  NUMBER;
  BEGIN
    SELECT NVL(sal_restringido, 0)
      INTO v_rest
      FROM md_cta_documentos
     WHERE nro_cuenta = p_nro_cuenta
       AND cod_modulo = 10;
    v_fli := fu_suma_fli_vigente(p_nro_cuenta, p_nro_documento);
    RETURN v_rest = 0 AND v_fli = 0;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
  END fu_ok_origen_limpio;

  --- DISP(origen) ≥ monto_deseado
  FUNCTION fu_ok_disp_para_venta(p_nro_cuenta    IN md_cta_documentos.nro_cuenta%TYPE,
                                 p_monto_deseado IN md_cta_documentos.monto%TYPE)
    RETURN BOOLEAN IS
  BEGIN
    RETURN fu_calc_disp(p_nro_cuenta) >= p_monto_deseado;
  END fu_ok_disp_para_venta;

  PROCEDURE pr_assert_origen_post_reasigna(p_nro_cuenta    IN  md_cta_documentos.nro_cuenta%TYPE,
                                           p_nro_documento IN  md_cta_documentos.nro_documento%TYPE,
                                           p_monto_deseado IN  md_cta_documentos.monto%TYPE,
                                           p_cod_error     OUT NUMBER,
                                           p_des_error     OUT VARCHAR2,
                                           p_exigir_origen_limpio IN BOOLEAN DEFAULT TRUE) IS
  BEGIN
    p_cod_error := cg_fli_ok;
    p_des_error := NULL;

    --- Venta total: origen limpio. Venta parcial: solo DISP >= monto
    IF p_exigir_origen_limpio THEN
      IF NOT fu_ok_origen_limpio(p_nro_cuenta, p_nro_documento) THEN
        pr_set_error_r5(p_cod_error, p_des_error);
        RETURN;
      END IF;
    END IF;

    IF NOT fu_ok_disp_para_venta(p_nro_cuenta, p_monto_deseado) THEN
      pr_set_error_r5(p_cod_error, p_des_error);
      RETURN;
    END IF;
  END pr_assert_origen_post_reasigna;

  FUNCTION fu_requiere_reasigna_fli(p_nro_cuenta      IN md_cta_documentos.nro_cuenta%TYPE,
                                    p_nro_documento   IN md_cta_documentos.nro_documento%TYPE,
                                    p_monto_deseado   IN md_cta_documentos.monto%TYPE,
                                    p_sal_restringido IN md_cta_documentos.sal_restringido%TYPE DEFAULT NULL)
    RETURN BOOLEAN IS
    v_disp NUMBER;
  BEGIN
    --- Venta parcial y total: reasignar SOLO si monto_deseado > DISP.
    --- DISP = monto − sal_restringido − garantia FLI.
    --- Si DISP >= monto_deseado → no-op (vende contra disponible).
    v_disp := fu_calc_disp(p_nro_cuenta);
    RETURN NVL(p_monto_deseado, 0) > NVL(v_disp, 0);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
  END fu_requiere_reasigna_fli;

  PROCEDURE pr_sync_ge_cuentas_documento(p_nro_documento IN md_cta_documentos.nro_documento%TYPE) IS
    v_fec_proceso ge_cuentas.fec_cam_estado%TYPE;
  BEGIN
    v_fec_proceso := pag_cal.fu_obt_fec_actual(10);

    UPDATE ge_cuentas g
       SET g.estado = (
             SELECT d.estado
               FROM md_cta_documentos d
              WHERE d.nro_cuenta = g.nro_cuenta
                AND d.cod_modulo = 10),
           g.fec_cam_estado = v_fec_proceso
     WHERE g.cod_modulo = 10
       AND g.nro_cuenta IN (
             SELECT d.nro_cuenta
               FROM md_cta_documentos d
              WHERE d.nro_documento = p_nro_documento
                AND d.cod_modulo = 10);
  END pr_sync_ge_cuentas_documento;

  PROCEDURE pr_fase_a_traslado_sal_restringido(p_nro_cuenta_orig IN md_cta_documentos.nro_cuenta%TYPE,
                                               p_nro_documento   IN md_cta_documentos.nro_documento%TYPE,
                                               p_cod_error       OUT NUMBER,
                                               p_des_error       OUT VARCHAR2,
                                               p_mto_maximo      IN NUMBER DEFAULT NULL) IS
    /* traslada sal_restringido a destinos
       p_mto_maximo NULL = todo el rest (venta total).
       p_mto_maximo > 0  = solo hasta ese monto (venta parcial / faltante). */
    v_rest_orig NUMBER;
    v_a_mover   NUMBER;
    v_pendiente NUMBER;
    v_mover     NUMBER;
    v_cap       NUMBER;
    v_rest_fin  NUMBER;
    v_fli_fin   NUMBER;
    r_dest      cur_destinos_fli%ROWTYPE;
  BEGIN
    SELECT NVL(sal_restringido, 0)
      INTO v_rest_orig
      FROM md_cta_documentos
     WHERE nro_cuenta = p_nro_cuenta_orig
       FOR UPDATE;

    IF v_rest_orig <= 0 THEN
      RETURN;
    END IF;

    IF p_mto_maximo IS NULL THEN
      v_a_mover := v_rest_orig;
    ELSE
      v_a_mover := LEAST(v_rest_orig, GREATEST(NVL(p_mto_maximo, 0), 0));
    END IF;

    IF v_a_mover <= 0 THEN
      RETURN;
    END IF;

    v_pendiente := v_a_mover;

    OPEN cur_destinos_fli(p_nro_documento, p_nro_cuenta_orig);
    LOOP
      FETCH cur_destinos_fli INTO r_dest;
      EXIT WHEN cur_destinos_fli%NOTFOUND;

      IF v_pendiente <= 0 THEN
        EXIT;
      END IF;

      IF fu_calc_disp(r_dest.nro_cuenta) <= 0 THEN
        CONTINUE;
      END IF;

      v_cap := fu_capacidad_rest_dest(r_dest.nro_cuenta);
      IF v_cap <= 0 THEN
        CONTINUE;
      END IF;

      v_mover := LEAST(v_pendiente, v_cap);

      IF NOT fu_ok_rest_fli_vs_monto_proy(r_dest.nro_cuenta, v_mover, 0) THEN
        p_cod_error := cg_fli_err_integridad;
        p_des_error := 'rest+FLI supera monto en cuenta destino ' || r_dest.nro_cuenta;
        CLOSE cur_destinos_fli;
        RETURN;
      END IF;

      UPDATE md_cta_documentos
         SET sal_restringido = NVL(sal_restringido, 0) + v_mover,
             estado          = 'T'
       WHERE nro_cuenta = r_dest.nro_cuenta;

      v_pendiente := v_pendiente - v_mover;
    END LOOP;
    CLOSE cur_destinos_fli;

    IF v_pendiente > 0 THEN
      pr_set_error_r5(p_cod_error, p_des_error);
      RETURN;
    END IF;

    v_rest_fin := v_rest_orig - v_a_mover;
    v_fli_fin  := fu_suma_fli_vigente(p_nro_cuenta_orig, p_nro_documento);

    UPDATE md_cta_documentos
       SET sal_restringido = v_rest_fin,
           estado          = CASE
                               WHEN v_rest_fin > 0 OR v_fli_fin > 0 THEN 'T'
                               ELSE 'C'
                             END
     WHERE nro_cuenta = p_nro_cuenta_orig;

    p_cod_error := cg_fli_ok;
    p_des_error := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      IF cur_destinos_fli%ISOPEN THEN
        CLOSE cur_destinos_fli;
      END IF;
      RAISE;
  END pr_fase_a_traslado_sal_restringido;

  PROCEDURE pr_fase_b_reasigna_fli(p_nro_cuenta_orig IN md_cta_documentos.nro_cuenta%TYPE,
                                   p_nro_documento   IN md_cta_documentos.nro_documento%TYPE,
                                   p_cod_error       OUT NUMBER,
                                   p_des_error       OUT VARCHAR2) IS
    /* reasignación FLI (mismo nro_referencia + nro_documento):
       - Origen: siempre permanece; situacion V → N (deja de contar como garantía)
       - Destino con fila V: acumula monto; permanece V
       - Destino sin fila: INSERT copia con situacion V
       - Destino con fila N/L (misma clave): NO reutilizar → omitir destino (UK)
       - Contable: baja origen (824) + alta destino (823) via PAM_FRC
       Condición: rest + FLI proyectado del destino ≤ monto (M3) y DISP ≥ mto FLI. */
    r_fli           cur_fli_origen_doc%ROWTYPE;
    r_dest          cur_destinos_fli%ROWTYPE;
    v_asignado      BOOLEAN;
    v_mto_fli       NUMBER;
    v_dest_hit      NUMBER;
    v_bloq_uk       NUMBER;
    v_nro_secuencia NUMBER := 0;
    v_cod_conta     NUMBER;
    v_des_conta     VARCHAR2(4000);
  BEGIN
    OPEN cur_fli_origen_doc(p_nro_cuenta_orig, p_nro_documento);
    LOOP
      FETCH cur_fli_origen_doc INTO r_fli;
      EXIT WHEN cur_fli_origen_doc%NOTFOUND;

      v_mto_fli  := NVL(r_fli.monto, 0);
      v_asignado := FALSE;

      OPEN cur_destinos_fli(p_nro_documento, p_nro_cuenta_orig);
      LOOP
        FETCH cur_destinos_fli INTO r_dest;
        EXIT WHEN cur_destinos_fli%NOTFOUND;

        IF fu_calc_disp(r_dest.nro_cuenta) < v_mto_fli THEN
          CONTINUE;
        END IF;

        --- sal_restringido + FLI (incl. monto a acumular) ≤ monto cuenta destino
        IF NOT fu_ok_rest_fli_vs_monto_proy(r_dest.nro_cuenta, 0, v_mto_fli) THEN
          CONTINUE;
        END IF;

        --- Destino: acumular SOLO sobre fila vigente (V). N/L no se reutilizan.
        UPDATE sb_snp_fli d
           SET d.monto            = NVL(d.monto, 0) + v_mto_fli,
               d.situacion        = 'V',
               d.usu_modificacion = USER,
               d.fec_modificacion = SYSDATE
         WHERE d.nro_cuenta = r_dest.nro_cuenta
           AND d.nro_referencia = r_fli.nro_referencia
           AND TRIM(d.nro_documento) = TRIM(p_nro_documento)
           AND d.situacion = 'V';

        v_dest_hit := SQL%ROWCOUNT;

        IF v_dest_hit = 0 THEN
          --- ¿Existe fila N/L u otra no-V con misma clave lógica? UK impide INSERT.
          SELECT COUNT(*)
            INTO v_bloq_uk
            FROM sb_snp_fli d
           WHERE d.nro_cuenta = r_dest.nro_cuenta
             AND d.nro_referencia = r_fli.nro_referencia
             AND TRIM(d.nro_documento) = TRIM(p_nro_documento)
             AND NVL(d.situacion, 'X') <> 'V';

          IF v_bloq_uk > 0 THEN
            CONTINUE; --- no reactivar N/L; probar siguiente destino
          END IF;

          --- Sin fila en destino: INSERT vigente
          INSERT INTO sb_snp_fli
            (nro_referencia, nro_documento, cod_msj_swift, fecha, msj_swift,
             cod_moneda, monto, error, situacion, fec_recepcion, msj_swi_original,
             nro_ref_externa, nro_cuenta, mto_letra,
             usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
            SELECT o.nro_referencia,
                   o.nro_documento,
                   o.cod_msj_swift,
                   o.fecha,
                   o.msj_swift,
                   o.cod_moneda,
                   o.monto,
                   o.error,
                   'V',
                   o.fec_recepcion,
                   o.msj_swi_original,
                   o.nro_ref_externa,
                   r_dest.nro_cuenta,
                   o.mto_letra,
                   USER,
                   SYSDATE,
                   USER,
                   SYSDATE
              FROM sb_snp_fli o
             WHERE o.nro_referencia = r_fli.nro_referencia
               AND o.nro_cuenta = p_nro_cuenta_orig
               AND TRIM(o.nro_documento) = TRIM(p_nro_documento)
               AND o.situacion = 'V';
        END IF;

        --- Origen: siempre permanece con situacion N (monto intacto)
        UPDATE sb_snp_fli
           SET situacion        = 'N',
               usu_modificacion = USER,
               fec_modificacion = SYSDATE
         WHERE nro_referencia = r_fli.nro_referencia
           AND nro_cuenta = p_nro_cuenta_orig
           AND TRIM(nro_documento) = TRIM(p_nro_documento)
           AND situacion = 'V';

        UPDATE md_cta_documentos
           SET estado = 'T'
         WHERE nro_cuenta = r_dest.nro_cuenta;

        --- Imputacion contable: baja origen + alta destino (misma secuencia)
        pr_conta_reasigna_garantia_fli(
          p_nro_cuenta_orig => p_nro_cuenta_orig,
          p_nro_cuenta_dest => r_dest.nro_cuenta,
          p_monto           => v_mto_fli,
          p_ref_543         => r_fli.nro_ref_externa,
          p_cod_error       => v_cod_conta,
          p_des_error       => v_des_conta,
          p_nro_secuencia   => v_nro_secuencia);

        IF v_cod_conta <> cg_fli_ok THEN
          CLOSE cur_destinos_fli;
          CLOSE cur_fli_origen_doc;
          p_cod_error := v_cod_conta;
          p_des_error := v_des_conta;
          RETURN;
        END IF;

        v_asignado := TRUE;
        EXIT;
      END LOOP;
      CLOSE cur_destinos_fli;

      IF NOT v_asignado THEN
        CLOSE cur_fli_origen_doc;
        pr_set_error_r5(p_cod_error, p_des_error);
        RETURN;
      END IF;
    END LOOP;
    CLOSE cur_fli_origen_doc;

    p_cod_error := cg_fli_ok;
    p_des_error := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      IF cur_destinos_fli%ISOPEN THEN
        CLOSE cur_destinos_fli;
      END IF;
      IF cur_fli_origen_doc%ISOPEN THEN
        CLOSE cur_fli_origen_doc;
      END IF;
      RAISE;
  END pr_fase_b_reasigna_fli;

  PROCEDURE pr_reasigna_reserva_fli(p_nro_cuenta    IN  md_cta_documentos.nro_cuenta%TYPE,
                                    p_monto_deseado IN  md_cta_documentos.monto%TYPE,
                                    p_cod_error     OUT NUMBER,
                                    p_des_error     OUT VARCHAR2,
                                    p_es_parcial    IN  VARCHAR2 DEFAULT 'N') IS
    r_orig           md_cta_documentos%ROWTYPE;
    v_rest_orig      NUMBER;
    v_fli_doc_orig   NUMBER;
    v_disp           NUMBER;
    v_faltante       NUMBER;
    v_es_parcial     BOOLEAN;
  BEGIN
    p_cod_error := cg_fli_ok;
    p_des_error := NULL;
    v_es_parcial := (UPPER(NVL(p_es_parcial, 'N')) = 'S');

    IF p_monto_deseado IS NULL OR p_monto_deseado <= 0 THEN
      p_cod_error := cg_fli_err_param;
      p_des_error := 'Monto deseado invalido';
      RETURN;
    END IF;

    BEGIN
      SELECT *
        INTO r_orig
        FROM md_cta_documentos
       WHERE nro_cuenta = p_nro_cuenta
         AND cod_modulo = 10
         FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        p_cod_error := cg_fli_err_param;
        p_des_error := 'Cuenta origen no encontrada';
        RETURN;
    END;

    IF r_orig.estado NOT IN ('C', 'T', 'R') THEN
      p_cod_error := cg_fli_err_estado;
      p_des_error := 'Cuenta origen no vendible';
      RETURN;
    END IF;

    IF fu_ok_rest_vs_monto(p_nro_cuenta) = 'N' THEN
      p_cod_error := cg_fli_err_integridad;
      p_des_error := 'sal_restringido supera monto en cuenta origen';
      RETURN;
    END IF;

    v_rest_orig := NVL(r_orig.sal_restringido, 0);

    --- Solo si monto_deseado > DISP
    IF NOT fu_requiere_reasigna_fli(p_nro_cuenta,
                                    r_orig.nro_documento,
                                    p_monto_deseado,
                                    r_orig.sal_restringido) THEN
      RETURN;
    END IF;

    v_disp     := fu_calc_disp(p_nro_cuenta);
    v_faltante := GREATEST(NVL(p_monto_deseado, 0) - NVL(v_disp, 0), 0);

    SAVEPOINT sp_reasigna_fli;

    --- Fase A: sal_restringido
    --- Parcial: solo el faltante. Total: todo el rest.
    IF v_rest_orig > 0 THEN
      pr_fase_a_traslado_sal_restringido(
        p_nro_cuenta_orig => p_nro_cuenta,
        p_nro_documento   => r_orig.nro_documento,
        p_cod_error       => p_cod_error,
        p_des_error       => p_des_error,
        p_mto_maximo      => CASE WHEN v_es_parcial THEN v_faltante ELSE NULL END);
      IF p_cod_error <> cg_fli_ok THEN
        ROLLBACK TO sp_reasigna_fli;
        RETURN;
      END IF;
    END IF;

    --- Fase B: FLI
    --- Parcial: solo si tras A sigue faltando DISP. Total: siempre si queda FLI
    SELECT NVL(SUM(f.monto), 0)
      INTO v_fli_doc_orig
      FROM sb_snp_fli f
     WHERE f.nro_cuenta = p_nro_cuenta
       AND f.nro_documento = r_orig.nro_documento
       AND f.situacion = 'V';

    IF v_fli_doc_orig > 0 THEN
      IF (NOT v_es_parcial)
         OR (fu_calc_disp(p_nro_cuenta) < p_monto_deseado) THEN
        pr_fase_b_reasigna_fli(p_nro_cuenta,
                               r_orig.nro_documento,
                               p_cod_error,
                               p_des_error);
        IF p_cod_error <> cg_fli_ok THEN
          ROLLBACK TO sp_reasigna_fli;
          RETURN;
        END IF;
      END IF;
    END IF;

    pr_assert_origen_post_reasigna(p_nro_cuenta,
                                   r_orig.nro_documento,
                                   p_monto_deseado,
                                   p_cod_error,
                                   p_des_error,
                                   p_exigir_origen_limpio => (NOT v_es_parcial));
    IF p_cod_error <> cg_fli_ok THEN
      ROLLBACK TO sp_reasigna_fli;
      RETURN;
    END IF;

    pr_sync_ge_cuentas_documento(r_orig.nro_documento);

  END pr_reasigna_reserva_fli;

end PAM_DOC;
/
