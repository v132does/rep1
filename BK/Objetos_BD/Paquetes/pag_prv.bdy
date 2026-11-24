CREATE OR REPLACE PACKAGE BODY IT.PAG_PRV IS

FUNCTION fu_generarBitacora(error in varchar2, nombreRespuesta in varchar2 ,descripcionRespuesta in varchar2, mensajesAdicionales in varchar2 := NULL) RETURN VARCHAR2 IS
      v_linea    VARCHAR2(1000);
      v_paquete  VARCHAR2(1000);
      v_llamador VARCHAR2(1000);
      v_duenho   VARCHAR2(1000);
   BEGIN
      OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador);
      RETURN v_paquete || '.' || v_linea || sys_context('USERENV', 'ACTION') || ' Userid:' || sys_context('USERENV', 'SESSION_USER') || ' Ip:' || sys_context('USERENV', 'IP_ADDRESS') || ' isDBA:' || sys_context('USERENV', 'ISDBA') || ' Error:' ||(CASE error WHEN 'S' THEN 'T' WHEN 'N' THEN 'F' END) || ' nombreRespuesta:' || nombreRespuesta || ' descripcionRespuesta:' || descripcionRespuesta;
   END;

/* Obtener datos parámetros de empresas   pago proveedores */
PROCEDURE PR_OBT_DAT_PROVEEDOR
 (P_EMPRESA IN NUMBER
 ,P_DESCRIPCION OUT VARCHAR2
 ,P_TIP_COMPROBANTE OUT VARCHAR2
 ,P_COD_TRA_PADRE OUT NUMBER
 ,P_CTA_DEBITO OUT VARCHAR2
 ,P_PAG_FAC_ATRASADA OUT VARCHAR2
 ,P_REF_TXT OUT VARCHAR2
 ,P_COD_TRA_DEBITO OUT NUMBER
 ,P_RUB_DEBITO     OUT VARCHAR2
 )
 IS
------------------------------------------------------------
 /* Obtener datos de la empresa */
begin

  SELECT descripcion
    INTO p_descripcion
    FROM GE_ENTES
   WHERE cod_ente = p_empresa;
   ------------------------------------------
 -- Se debe obtener los demas parametros...
   ------------------------------------------
  p_tip_comprobante := fug_obt_parentes(p_empresa, 'TIP_COB_PPROV');

  IF p_tip_comprobante IS NULL THEN
   RAISE_APPLICATION_ERROR(-20300,'La empresa no definio Tipo Comprobante. Verifique!!!');
  END IF;

  p_cod_tra_padre := fug_obt_parentes(p_empresa, 'COD_TRA_PAD_PPROV');

  if p_cod_tra_padre IS NULL then
   RAISE_APPLICATION_ERROR(-20320,'La empresa no posee Transaccion Padre. Verifique!!!');
  end if;

  p_cta_debito := fug_obt_parentes(p_empresa, 'CTA_DEB_PPROV');

  P_rub_debito := fug_obt_parentes(p_empresa, 'COD_RUB_PPROV');

  if p_cta_debito IS NULL and p_rub_debito is null then
   RAISE_APPLICATION_ERROR(-20330,'La empresa no posee Cuenta de Debito(Cuenta o Rubro). Verifique!!!');
  end if;

  p_pag_fac_atrasada := fug_obt_parentes(p_empresa, 'PAG_FAC_ATRASADA');

  if p_pag_fac_atrasada is null then
   RAISE_APPLICATION_ERROR(-20340,'La empresa no tiene definido Pagos Atrasados. Verifique!!!');
  end if;

  p_ref_txt := fug_obt_parentes(p_empresa, 'REF_TXT_PPROV');

  if p_ref_txt is null and p_rub_debito is null then
   RAISE_APPLICATION_ERROR(-20370,'La empresa no tiene definido archivo txt. Verifique!!!');
  end if;

  --p_cod_tra_debito := 503;
    p_cod_tra_debito := 7503;--rubro proyecto pago a proveedores

EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20400,'Empresa Inexistente... Verifique.');
  WHEN TOO_MANY_ROWS THEN
   RAISE_APPLICATION_ERROR(-20450,'Empresa Duplicada... AVISE AL ADMINISTRADOR.');
  when others then
   if sqlcode <= -20000 then
      raise;
   else
      RAISE_APPLICATION_ERROR(-20450,'Al recup. datos de la Empresa. '||sqlerrm);
   end if;
end pr_obt_dat_proveedor;
/* Obtener parámetros de ente adicionales */
PROCEDURE PR_OBT_PAR_PROVEEDOR
 (P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE
 ,P_COD_TRA_PAD_CREDITO OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TRA_COM_MENSUAL OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TRA_COM_INDIVIDUAL OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TRA_COM_SERVICIO OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_REF_TXT_MON_FUERTE OUT GE_PAR_ENTES.VAL_PARAMETRO%TYPE
 ) IS
BEGIN
   P_COD_TRA_PAD_CREDITO    := fug_obt_parentes(P_COD_ENTE, 'COD_TRA_PAD_PRV_CREDITO');
   P_COD_TRA_COM_MENSUAL    := fug_obt_parentes(P_COD_ENTE, 'COD_TRA_COM_MENSUAL');
   P_COD_TRA_COM_INDIVIDUAL := fug_obt_parentes(P_COD_ENTE, 'COD_TRA_COM_INDIVIDUAL');
   P_COD_TRA_COM_SERVICIO   := fug_obt_parentes(P_COD_ENTE, 'COD_TRA_COM_SERVICIO');
   P_REF_TXT_MON_FUERTE     := fug_obt_parentes(P_COD_ENTE, 'REF_TXT_PPROV_USD');

END;
/* Insertar en GE_PAG_PROVEEDORES desde el TMP */
PROCEDURE PR_INS_GE_PAG_PROVEEDORES
 (P_COD_EMPRESA IN NUMBER
 ,P_FECHA IN DATE
 ,P_ERROR OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 )
 IS
/* Inserta en la tabla GE_PAG_PROVEEDORES */
begin
   insert into ge_pag_proveedores
              (nro_orden,
               nro_factura,
               tip_comprobante,
               for_pago,
               nro_cheque,
               nro_cta_credito,
               nro_cta_debito,
               fec_ingreso,
               fec_pago,
               monto,
               nro_recibo,
               beneficiario,
               concepto,
               estado,
               cod_usu_operador,
               cod_ente,
               cod_moneda,
               tip_carga,
               ref_facturas,
               referencia,
               mon_tot_recibo,
               ret_fac_proveedor,
               des_fac_proveedor,
               ret_facturas,
               des_sucursal,
               nro_archivo,
               ent_bca_beneficiario,
               cod_tip_doc_beneficiario,
               nro_doc_beneficiario,
               ind_valor,
               nro_cta_beneficiario,
               dir_beneficiario,
               tip_factura,
               nro_con_cambio,
               ben_dir_correo,
               nro_ord_archivo
                )
           select nro_orden,
                  nro_factura,
                  tip_comprobante,
                  for_pago,
                  nro_cheque,
                  nro_cta_credito,
                  nro_Cta_debito,
                  fec_ingreso,
                  fec_pago,
                  monto,
                  nro_recibo,
                  beneficiario,
                  concepto,
                  estado,
                  cod_usu_operador,
                  cod_ente,
                  cod_moneda,
                  tip_carga,
                  ref_facturas,
                  referencia,
                  mon_tot_recibo,
                  ret_fac_proveedor,
                  des_fac_proveedor,
                  ret_facturas,
                  des_sucursal,
                  nro_archivo,
                  ent_bca_beneficiario,
                  cod_tip_doc_beneficiario,
                  nro_doc_beneficiario,
                  ind_valor,
                  nro_cta_beneficiario,
                  dir_beneficiario,
                  tip_factura,
                  nro_con_cambio,
                  ben_dir_correo,
                  nro_ord_archivo
             from ge_pag_proveedores_tmp
            where cod_ente = p_cod_empresa
              and trunc(fec_insercion) = trunc(p_fecha)
              and usu_insercion = user
              and nvl(tipo,'C') = 'C'
              and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

         if sql%notfound then
            p_error := '-20099, Insertar en ge_pag_proveedores. No existen datos en el tmp';
            --RAISE_APPLICATION_ERROR(-20099,'Insertar en ge_pag_proveedores. No existen datos en el tmp');
         else
            p_error := null;
         end if;
exception
   when dup_val_on_index then
      p_error := '-20199, Registro ya existe en pag_proveedores.';
      --RAISE_APPLICATION_ERROR(-20199,'Registro ya existe en pag_proveedores.');
end PR_INS_GE_PAG_PROVEEDORES;
/* Borra Datos de la tabla GE_PAG_PROVEEDORES_TMP */
PROCEDURE PR_ELI_PROV_TMP
 (P_COD_EMPRESA IN NUMBER,
  P_FEC_PROCESO IN DATE DEFAULT NULL,
  P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 )
 IS
v_usuario             ba_usuarios.cod_usuario%TYPE := substr(user,  1, 10);
/* Borra los datos procesados del temporal DE PROVEEDORES */
begin
  --DDSI-1679 USER tiene en cuenta el usuario de itgf y tambien de digitales
  v_usuario := USER;
   if v_usuario in ('HBANK', 'BBVAAPIUSR') then
       v_usuario := 'HBANK'; --Solo se cambia con digitales ya que el registro se da desde hbank
  end if;

    DELETE GE_PAG_PROVEEDORES_TMP
     WHERE (COD_ENTE = p_cod_empresa or COD_ENTE is null)
       --AND USU_INSERCION = USER Se comenta ya que no tiene en cuenta el usuario de EMA BBVAAPIUSR
       AND USU_INSERCION = v_usuario -- tratado en el DDSI-1679
       AND (P_FEC_PROCESO IS NULL OR TRUNC(FEC_INSERCION) = TRUNC(P_FEC_PROCESO))
       AND nvl(NRO_ARCHIVO, 0) = nvl(P_NRO_ARCHIVO, 0);
exception
 When others then
  RAISE_APPLICATION_ERROR(-20010,'Borrar GE_PAG_PROVEEDORES_TMP ');
end PR_ELI_PROV_TMP;

/*Devolver la cuenta en formato IT*/
 FUNCTION Fu_ver_cuenta
 (p_cta in varchar2)
 return varchar2
 is
BEGIN
  if  substr(p_cta,3,6) in('210100','215000') then
    return  (substr(p_cta,1,2)||'01'||substr(p_cta,9,6));
  elsif substr(p_cta,3,6) in('210500','215500') then
    return  (substr(p_cta,1,2)||'02'||substr(p_cta,9,6));
  End if;
END;

/*Devolver la cantidad de digitos de cuenta real*/
 FUNCTION Fu_val_cuenta
 (p_cta in varchar2)
 return varchar2
 is
BEGIN
  if  length(p_cta) = 9 then
    return  '0'||p_cta;
  else
    return  p_cta;
  End if;
END;

FUNCTION FU_OBT_NRO_SECUENCIA(P_COD_ENTE IN NUMBER,
                              P_FEC_PAGO IN DATE) RETURN NUMBER IS
  v_nro_archivo     ge_pag_proveedores_tmp.nro_archivo%type := 0;
  v_aux_nro_archivo ge_pag_proveedores_tmp.nro_archivo%type;
BEGIN
  select nvl(max(nro_archivo), 0) -- el tmp no tiene fec pago
    into v_aux_nro_archivo
    from ge_pag_proveedores_tmp t
   where t.cod_ente = P_COD_ENTE
     and trunc(t.fec_insercion) = trunc(sysdate);

  if v_nro_archivo < v_aux_nro_archivo then
    v_nro_archivo := v_aux_nro_archivo;
  end if;

  select nvl(max(nro_archivo), 0)
    into v_aux_nro_archivo
    from ge_pag_proveedores t
   where t.cod_ente = P_COD_ENTE
     and trunc(t.fec_insercion) = trunc(sysdate);

  if v_nro_archivo < v_aux_nro_archivo then
    v_nro_archivo := v_aux_nro_archivo;
  end if;

  -- para pago fecha futura
  select nvl(max(nro_archivo), 0)
    into v_aux_nro_archivo
    from ge_pag_proveedores t
   where t.cod_ente = P_COD_ENTE
     and trunc(t.fec_pago) = trunc(P_FEC_PAGO);

  if v_nro_archivo < v_aux_nro_archivo then
    v_nro_archivo := v_aux_nro_archivo;
  end if;

  select nvl(max(nro_archivo), 0)
    into v_aux_nro_archivo
    from ge_pag_proveedores_tmp t
   where t.cod_ente = P_COD_ENTE
     and trunc(t.fec_pago) = trunc(P_FEC_PAGO);

  if v_nro_archivo < v_aux_nro_archivo then
    v_nro_archivo := v_aux_nro_archivo;
  end if;

  v_nro_archivo := v_nro_archivo + 1;

  return v_nro_archivo;
END;

/*Formato recibido de Mapfre - Devolver la cuenta en formato IT*/
 FUNCTION Fu_ver_cuenta_map
 (p_cta in varchar2)
 return varchar2
 is
BEGIN
  if  substr(p_cta,3,1) = 'A' then  -- Ahorro
    return  (substr(p_cta,1,2)||'02'||substr(p_cta,4,6));
  elsif  substr(p_cta,3,1) = 'C' then  -- Cta.Cte.
    return  (substr(p_cta,1,2)||'01'||substr(p_cta,4,6));
  End if;
END;


/* Insertar en la tabla GE_PAG_PRO_FACTURAS desde el TMP */
PROCEDURE PR_INS_GE_PAG_PRO_FACTURAS
 (P_COD_EMPRESA IN NUMBER
 ,P_FECHA IN DATE
 ,P_ERROR OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 )
 IS
------------------------------------------------------------
/* Inserta en la tabla GE_PAG_PRO_FACTURAS */
begin
   insert into ge_pag_pro_facturas
              (nro_orden,
               fec_carga,
               nro_factura,
               mto_total,
               concepto,
               cod_ente )
         select nro_orden,
                fec_carga,
                nro_factura,
                mto_total,
                concepto,
                cod_ente
           from ge_pag_pro_facturas_tmp
          where cod_ente = p_cod_empresa
            and trunc(fec_insercion) = trunc(p_fecha)
            and usu_insercion = user
            and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

           if sql%notfound then
              p_error :='-20097, Insertar en ge_pag_pro_facturas. No existen datos en el tmp';
              --RAISE_APPLICATION_ERROR(-20097,'Insertar en ge_pag_pro_facturas.No existen datos en el tmp');
           else
              p_error := null;
           end if;
exception
   when dup_val_on_index then
      p_error := '-20199,Registro ya existe en pag_pro_facturas.';
      --RAISE_APPLICATION_ERROR(-20199,'Registro ya existe en pag_pro_facturas.');
end PR_INS_GE_PAG_PRO_FACTURAS;
/* Borra datos del temporal GE_PAG_FACTURAS_TMP */
PROCEDURE PR_ELI_FAC_TMP
 (P_COD_EMPRESA IN NUMBER,
  P_FEC_PROCESO IN DATE DEFAULT NULL,
  P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 )
 IS
  v_usuario             ba_usuarios.cod_usuario%TYPE := substr(user,  1, 10);
/* Borra los datos procesados del temporal FACTURAS DE PROVEEDORES */
begin
  v_usuario := USER;
   if v_usuario in ('HBANK', 'BBVAAPIUSR') then
       v_usuario := 'HBANK'; --Solo se cambia con digitales ya que el registro se da desde hbank
   end if;

    DELETE GE_PAG_PRO_FACTURAS_TMP
     WHERE COD_ENTE = p_cod_empresa
       AND USU_INSERCION = v_usuario
       AND (P_FEC_PROCESO IS NULL OR TRUNC(FEC_INSERCION) = TRUNC(P_FEC_PROCESO))
       AND nvl(NRO_ARCHIVO, 0) = nvl(P_NRO_ARCHIVO, 0);
exception
 When others then
  RAISE_APPLICATION_ERROR(-20010,'Borrar GE_PAG_PRO_FACTURAS_TMP ');
end PR_ELI_FAC_TMP;
/* Cobra Impuesto ley 125 */
/*PROCEDURE PR_OBT_IMPUESTO
 (P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 )
 IS

v_val_base          number(18,2) := p_monto;
v_fec_vigencia      date;
v_tip_valor         varchar2(1);
v_tipo              varchar2(1);
v_redondeo          number(1);
v_tas_personalizada varchar2(1);
begin
    p_cod_tra_impuesto := 571;  ---- se debe cambiar luego LEY 125 !!!

    -- veo si la cuenta tiene transaccion prohibida
  if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                 p_cod_tra_impuesto,
                                 p_cod_modulo,
                                 p_cod_modalidad) = 'N' then
    -- no tiene transaccion prohibida, se calcula
    begin
       select tas_personalizada
         into v_tas_personalizada
         from ge_cuentas
         where nro_cuenta = p_nro_cuenta;
    exception
       when no_data_found then
          raise_application_error(-20005,'Cuenta '||p_nro_cuenta||' no registrada');
    end;
    if p_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
      v_redondeo := 0;
    else
      v_redondeo := 2;
    end if;
    -- busco el valor de la tasa

    pag_gen.pr_obt_val_tasa(p_cod_modulo,
                            p_cod_modalidad,
                            p_cod_ofi_origen,
                            p_nro_cuenta,
                            p_cod_moneda,
                            v_val_base,
                            nvl(v_tas_personalizada,'N'),
                            p_cod_tas_impuesto,
                            p_cod_tra_impuesto,
                            trunc(sysdate),
                            p_val_tas_impuesto,
                            v_fec_vigencia,
                            v_tip_valor,
                            v_tipo);

    if v_tip_valor = 'V' then
       -- si es un valor, se toma directamente
       p_val_impuesto := nvl(p_val_tas_impuesto,0);
    else
       -- es un porcentaje
       p_val_impuesto := round(nvl(v_val_base,0)*
                               nvl(p_val_tas_impuesto,0)/100,v_redondeo);
    end if;

 end if;
end;*/
/* Verificar la cuenta de débito */


PROCEDURE PR_VER_CTA_DEBITO
 (P_CTA_DEBITO IN VARCHAR2
 ,P_ERROR     OUT VARchar2 )
 IS
  v_cod_modulo      ge_transacciones.cod_modulo%type;
  v_cod_modalidad   ge_transacciones.cod_modalidad%type;
  v_cod_moneda      ah_cta_vistas.cod_moneda%type;
  v_nro_cuenta      ge_cuentas.nro_cuenta%type;
  v_cta_combinada   ah_cta_vistas.cta_combinada%type;
  v_estado          ah_cta_vistas.estado%type;

Begin
  pag_cta.PR_OBT_CUENTA(P_cta_debito);
  if pag_cta.fu_obt_cod_error() <> 0 then
    p_error := 'Recup.Cta.Debito '||pag_cta.fu_obt_msj_error();
    return;
  end if;
  v_cod_moneda := pag_cta.g_ctas.cod_moneda;
  v_estado     := pag_cta.g_ctas.estado;
  v_cod_modulo := pag_cta.G_CTAS.cod_modulo;
  v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
  v_cta_combinada := pag_cta.g_ctas.cta_combinada;

  if v_cod_modalidad not in (31,41,334) then
    p_error     := 'Modalidad Cta Debito no corresponde';
    return;
--  elsif v_cod_modalidad = 31 and v_cta_combinada = 'S' then
--    p_error     := 'Cta Debito de Ahorro es combinada';
--    return;
  end if;
  if v_estado in ('A','C','T','D') then
    p_error     := 'Estado de Cta Debito invalido';
    return;
  end if;
End;

/* Generar los cheques de Pago a Proveedores */
PROCEDURE PR_GEN_CHE_PROVEEDORES
 (P_COD_EMPRESA IN number
 ,P_FEC_PREVISTA IN date
 ,P_CHE_DESDE IN number
 ,P_CHE_HASTA IN number
 )
 IS
begin
declare
 v_desc_ente         ge_entes.descripcion%type;
 v_tip_comprobante   ge_pag_proveedores.tip_comprobante%type;
 v_cod_tra_padre     ge_transacciones.cod_transaccion%type;
 v_cta_debito     ge_cuentas.nro_cuenta%type;
 v_pag_fac_atrasada  varchar2(1);
 v_referencia_txt    varchar2(100);
 v_cod_tra_debito    ge_transacciones.cod_transaccion%type;
 v_cod_rubro         cb_rubros.cod_rubro%type;

 v_existe            varchar2(1);
 v_nro_cheque        number(15);
 v_cantidad          number(4);
 v_nro_cta_gerencia  varchar2(15);
 v_cod_oficina       ba_usuarios.cod_oficina%type;
 v_nro_che_gerencia  ge_pag_proveedores.nro_cheque%type;
 v_che_ger_desde     ge_pag_proveedores.nro_cheque%type;
 v_nro_che_inicial   number(15);
 v_msj_error         varchar2(3000);
 v_cod_moneda        varchar2(5);
 v_est_cheque        varchar2(1);
--todas las ordenes en cheques a pagarse en la fecha, sin restringir proveedor
 cursor CHEQUES IS
    select nro_cheque, cod_moneda, beneficiario , monto , nro_factura ,
          fec_ingreso , rowid
     from ge_pag_proveedores
    where fec_pago = p_fec_prevista
--            and (cod_tra_padre = v_cod_Tra_padre or v_cod_Tra_padre = 999)
      and for_pago = 'G'
      and estado in ('C', 'R') --cargado o reactivado
      and nro_cheque is null
      and rownum < (v_cantidad + 1)
    order by nro_orden, nro_factura;

cursor c_chequeras is
      select nro_che_inicial, (nvl(ult_che_emitido,nro_che_inicial-1))
        from cc_tip_chequeras b,cc_chequeras a
       where nro_cuenta = v_nro_cta_gerencia
         and estado = 'E'
         and nvl(ult_che_emitido,nro_che_inicial-1) < nro_che_final
         and nro_che_final - nvl(ult_che_emitido,nro_che_inicial-1) >= v_cantidad
         and b.cod_tip_chequera = a.tipo
         and b.can_cheques = '1' --  -- formulario continuo
       order by nvl(ult_che_emitido,nro_che_inicial-1);

--- PROCEDIMIENTO PARA ACTUALIZAR EN GE_PAG_PROVEEDORES EL NRO. DE CHEQUE GERENCIA A GENERAR
Begin
PRE_INI_APLICACION;
PAE_CNF.G_COD_MODULO:=1;

--* busco oficina
 begin
  select cod_oficina into v_cod_oficina from ba_usuarios where
    cod_usuario = user;
 exception
  when others then
      raise_application_error(20009,'Al Buscar oficina pago proveedor :'||sqlerrm);
 end;
--* proceso
    if p_che_desde is not null and nvl(p_che_hasta,p_che_desde) is not null then

      v_cantidad := (nvl(p_che_hasta,p_che_desde) - p_che_desde) + 1;
      PR_OBT_DAT_PROVEEDOR(p_cod_empresa,
                            v_desc_ente,
                            v_tip_comprobante,
                            v_cod_Tra_padre,
                            v_cta_debito,
                            v_pag_fac_atrasada,
                            v_referencia_txt,
                            v_cod_tra_debito,
                            v_cod_rubro);
        BEGIN
           select 'S' INTO v_existe
             from ge_pag_proveedores
            where fec_pago = p_fec_prevista
--              and (cod_tra_padre = v_cod_Tra_padre or  nvl(v_cod_Tra_padre,999) = 999 )
              and for_pago = 'G'
              and estado in ('C', 'R')
              and nro_cheque is null
              and rownum < (v_cantidad + 1 )
            order by nro_orden , nro_factura ;

            v_existe := 'S';
        EXCEPTION
          WHEN TOO_MANY_ROWS THEN v_existe := 'S';
          WHEN NO_DATA_FOUND THEN v_existe := 'N';
          WHEN OTHERS THEN
            Raise_application_error(-20001,'Generar los cheques p/Prov.'||sqlerrm);
        END;

        if v_existe = 'S' then
          -- busca la moneda de la cuenta
          select cod_moneda into v_cod_moneda
            from ge_cuentas
           where nro_cuenta = v_cta_debito;
          If v_cod_moneda is not null then
             v_nro_cta_gerencia := FUG_OBT_PARDINAMICO('NRO_CTA_BANCARIA',NULL,NULL,v_cod_moneda,v_cod_oficina);
          end if;
          open c_chequeras;
          fetch c_chequeras into v_nro_che_inicial, v_nro_che_gerencia;
          close c_chequeras;
          if v_nro_che_inicial is null then
             raise_application_error(-20000,'Error. No se puede utilizar esta numeracion de chequera. Verifique el rango y cheque Inicial');
          end if;
          BEGIN
           v_nro_cheque := v_nro_che_gerencia + 1;
           if v_nro_cheque <> p_che_desde then
              raise_application_error(-20000,'Nro de cheque inicial debe ser igual a '||v_nro_cheque);
           end if;
           -----------------------------------
           for var in cheques loop
            ----*
              v_est_cheque := pac_che.FU_OBT_EST_CHE(v_nro_cta_gerencia, v_nro_cheque, v_msj_error);
              if v_est_cheque <> 'E' or v_msj_error is not null then
                 raise_application_error(-20000,'Cheque '||v_nro_cheque||' con estado '||v_est_cheque||' - '||v_msj_error);
              end if;
              update ge_pag_proveedores
                set nro_cheque = v_nro_cheque
               where rowid = var.rowid;
              -----------------------------------
               v_nro_cheque := v_nro_cheque + 1;
              -----------------------------------
            end loop;
            update cc_chequeras
               set ult_che_emitido = v_nro_cheque
             where nro_cuenta = v_nro_cta_gerencia
               and nro_che_inicial = v_nro_che_inicial;
            If sql%notfound then
               raise_application_error(-20007, 'Al actualizar cc_chequeras :'||v_nro_cheque);
             End if;
            COMMIT;
          END;
        else
          raise_application_error(-20002, ' No existen cheques a Imprimir ');
        end if;
    end if;
 end;
end pr_gen_che_proveedores;
/* Funcion para obtener el estado del periodo sipap S: Abierto, N: Cerrado*/
FUNCTION lf_obt_hor_snp RETURN VARCHAR2 IS
   v_retorno VARCHAR2(1) := 'N';
BEGIN
   IF pas_snp.fu_obt_est_horario('103', '001', '002') = 'A' AND
      to_char(sysdate,'hh24mi') < paw_bas.fu_obt_hor_fin_snp(1) THEN --SDSIPAP247-1
      v_retorno := 'S';
   END IF;
   return v_retorno;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 'N';
END lf_obt_hor_snp;
/*verifica los datos del tmp y procesa si no hay errores*/
PROCEDURE PR_VER_DAT_TMP
(p_cod_ente in ge_entes.cod_ente%type,
 p_fec_pago1 in date,
 p_fec_pago2 in date,
 p_error out varchar2,
 p_procesar in varchar2,
 p_nro_documento in number default null,
 p_nro_cta_debito in ge_cuentas.nro_cuenta%type default null,
 p_nro_archivo in number default null,
 p_fec_insercion in date default null -- Modificaciones Fecha de Pago a Proveedores
 ) IS

  v_cod_proceso     number(3) := 0;
  v_cant            number(5);
  v_cantidad        number(10);

  v_cod_modulo      ge_transacciones.cod_modulo%type;
  v_cod_modalidad   ge_transacciones.cod_modalidad%type;
  v_cod_moneda      ah_cta_vistas.cod_moneda%type;
  v_nro_cuenta      ge_cuentas.nro_cuenta%type;
  v_estado          ah_cta_vistas.estado%type;
  v_cta_combinada   ah_cta_vistas.cta_combinada%type;
  v_cod_mon_credito ah_cta_vistas.cod_moneda%type;

  v_concepto         ge_pag_proveedores_tmp.concepto%type;
  v_fec_pago         date;
  v_nombre           varchar2(50);
  v_fec_actual       ge_calendarios.fec_actual%type := trunc(sysdate);--pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_descripcion      ge_entes.descripcion%type;
  v_tip_comprobante  ge_pag_proveedores.tip_comprobante%type;
  v_cod_tra_padre    ge_transacciones.cod_transaccion%type;
  v_cta_debito       ge_cuentas.nro_cuenta%type;
  v_cod_rubro        cb_rubros.cod_rubro%type;
  v_pag_atrasada     ge_pag_proveedores.tip_carga%type;
  v_ref_archivo      ge_archivos.referencia%type;
  v_cod_tra_debito   ge_transacciones.cod_transaccion%type;
  v_todetal  number(18,2);
  v_tocabec  number(18,2);
  v_cod_oficina      ba_oficinas.cod_oficina%type;
  v_existe           varchar2(1);
  v_nom_persona      ba_personas.nom_completo%type;
  v_tot_factura      number(18,2);
  v_can_duplicado    number(10) ;
  v_redondeo         number (8);
  v_hab_snp          varchar2(1);
  v_mto_max_ach      number(18,2);
  v_hor_snp_abierto  varchar2(1);
  v_fec_insercion    date :=p_fec_insercion;
  v_ind_valor        varchar2(1);
  v_ope_homebanking  varchar2(1) := 'N';
  v_can_usd          number(5);
  v_tip_carga      varchar2(1);
  v_cli_pue_enviar   varchar2(1);
  v_user             ba_usuarios.cod_usuario%TYPE := substr(user,  1, 10);

  cursor c_tmp is
    select *
      from ge_pag_proveedores_tmp
     where trunc(fec_insercion) = trunc(nvl(v_fec_insercion,v_fec_actual)) -- Mod.Fec.Pago Prov.
       and usu_insercion = v_user
       and (cod_ente = p_cod_ente or cod_ente is null)
       and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
       for update;

  cursor c_fac(p_nro_orden number) is
    select *
      from ge_pag_pro_facturas_tmp
     where trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
       and nro_orden = p_nro_orden
       and usu_insercion = v_user
       and (cod_ente = p_cod_ente or cod_ente is null)
       and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

/* calcular fecha de pago a proveedores */
FUNCTION fl_cal_fec_pago
(p_beneficiario in varchar2,
 p_nom_persona  in varchar2 )
RETURN date IS

v_fec_pago DATE := nvl(v_fec_insercion,v_fec_actual) + 1;--x defecto el día siguiente

BEGIN
  --si carga ambas fechas dividir en dos grupos
  if p_fec_pago1 is not null and p_fec_pago2 is not null then
    IF UPPER(SUBSTR(LTRIM(nvl(p_beneficiario,p_nom_persona)),1,1)) BETWEEN 'A' AND 'H' THEN
      v_fec_pago := p_fec_pago1;
    ELSE
      v_fec_pago := p_fec_pago2;
    END IF;
  elsif p_fec_pago1 is not null then --sino todo se paga en el mismo día
      v_fec_pago := p_fec_pago1;
  end if;
  --buscar siguiente día hábil si es feriado o no hábil
  v_fec_pago := pag_cal.FU_OBT_FEC_HABIL(v_fec_pago, 1, v_cod_oficina);

  RETURN v_fec_pago;
EXCEPTION
  WHEN OTHERS THEN
    p_error := 'Error al calcular fecha de pago '||sqlerrm;
END;
/* principal */
BEGIN
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  --recupera oficina del usuario
  begin
    select cod_oficina
      into v_cod_oficina
      from ba_usuarios
     where cod_usuario = user;
  exception
    when others then
      p_error := 'Recup.oficina del usuario '||sqlerrm;
      return;
  end;
  --recupera parámetros del ente.
  pag_prv.PR_OBT_DAT_PROVEEDOR(p_cod_ente, v_descripcion, v_tip_comprobante, v_cod_tra_padre, v_cta_debito,
                              v_pag_atrasada, v_ref_archivo, v_cod_tra_debito,v_cod_rubro);

  -- CR 03/09/2012 se agrega por opción de poder pagar con más de una cuenta
  if p_nro_cta_debito is not null then
     v_cta_debito := p_nro_cta_debito;
     v_ope_homebanking := 'S';
  end if;
  --
  begin
     v_mto_max_ach :=to_number(fug_obt_pardinamico('MTO_MAX_ACH'));
  exception
     when others then
        null;
  end;
  -- verifico el horario sipap
  v_hor_snp_abierto := lf_obt_hor_snp;

  -- Verifico la cuenta de débito
  if  v_cta_debito is not null then
    pag_cta.PR_OBT_CUENTA(v_Cta_debito);
    if pag_cta.fu_obt_cod_error() <> 0 then
      p_error := 'Recup.Cta.Debito '||pag_cta.fu_obt_msj_error();
      return;
    end if;
    v_cod_moneda := pag_cta.g_ctas.cod_moneda;
    v_estado     := pag_cta.g_ctas.estado;
    v_cod_modulo := pag_cta.G_CTAS.cod_modulo;
    v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
    v_cta_combinada := pag_cta.g_ctas.cta_combinada;

    -- CR para control de decimales
    -- v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
    --

    if v_cod_modalidad not in (31,41,334) then
      p_error     := 'Modalidad Cta Debito no corresponde';
      return;
    --elsif v_cod_modalidad = 31 and v_cta_combinada = 'S' then
     -- p_error     := 'Cta Debito de Ahorro es combinada';
      --return;
    end if;
    if v_estado in ('A','C','T','D') then
      p_error     := 'Estado de Cta Debito invalido';
      return;
    end if;
  End if;

  if FUG_OBT_PER_ENTIDAD <> FUE_OBT_PER_ENTE(p_cod_ente) then -- DYDMR-96. CB. 12/12/2013
    --actualiza los datos básicos del tmp para poder verificar, solo si no actualizo antes
    begin
      if user in ('HBANK', 'BBVAAPIUSR') then
       v_tip_carga := 'H';
       v_user := 'HBANK';
      else
       select decode(nvl(PAE_CNF.G_PROGRAMA,'X'),'X','H','A')
        into v_tip_carga
        from dual;
      end if;
       update ge_pag_proveedores_tmp set
           tip_comprobante    = v_tip_comprobante,
           estado             = 'C',        --- cargado
           cod_usu_operador   = user,
           cod_ente           = p_cod_ente,
           tip_carga          = v_tip_carga,
           nro_cta_debito     = v_cta_debito
        where trunc(fec_insercion) = trunc(nvl(v_fec_insercion,v_fec_actual))
         and usu_insercion = v_user --por el usuario
         and (cod_ente = p_cod_ente or cod_ente is null)
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
        /*if sql%notfound then    --para el reproceso
          p_error := 'No existe registro a actualizar en TMP de proveedores.';
          return;
        end if; */
    exception
       when others then
          p_error := 'Actualizar TMP de proveedores.'||sqlerrm;
          return;
    end;
  end if;
  --verifica q haya datos
  for reg in c_tmp loop
    v_existe := 'S';
    exit;
  end loop;
  if v_existe is null then
    p_error := 'No existen datos cargados en el tmp. Verifique';
    return;
  end if;
  -- Verifico que no existan lotes mixtos en horario cerrado SIPAP
  select count(*)
    into v_cant
    from(
          select decode(for_pago, 'I', 'I', 'X'), count(0)
            from ge_pag_proveedores_tmp
           where trunc(fec_insercion) = trunc(sysdate)
             and usu_insercion = v_user
             and cod_ente = p_cod_ente
             and nvl(tipo,'C') = 'C'
             and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
           group by decode(for_pago, 'I', 'I', 'X')
         );

   if v_cant = 2 and v_hor_snp_abierto = 'N' and trunc(p_fec_pago1) = trunc(sysdate) then --Mixto (interbancaria y otro)
      p_error := 'Horario SIPAP Cerrado, no se puede procesar archivo Mixto';
      return;
   end if;

   --MTOP SEP/2020 SDSIPAP247-1
   v_can_usd :=0;
   begin
     select count(*)
      into v_can_usd
      from ge_pag_proveedores_tmp
       where trunc(fec_insercion) = trunc(sysdate)
         and usu_insercion = v_user
         and cod_ente = p_cod_ente
         and nvl(tipo,'C') = 'C'
         and for_pago = 'I'  -- Interbancarias
         and cod_moneda <>  'GS'
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
   exception
      when no_data_found then
           v_can_usd :=0;
   end;
  v_hab_snp := upper(substr(trim(fug_obt_parentes(p_cod_ente, 'SNP_HAB_PROVEEDORES')), 1, 1));

  --recorre los registros del temporal para verificar datos: cta.credito, forma de pago , etc
  for reg in c_tmp loop
    v_concepto     := nvl(reg.concepto, 'Pago Proveedor '||reg.nro_factura);
    v_cod_proceso := 0;
    -- Verifico la cuenta de crédito
    if reg.for_pago = 'C' THEN -- crédito en cuenta
      if reg.nro_Cta_credito IS NULL THEN
         v_concepto := 'NO EXISTE CUENTA PARA EL CREDITO';
         v_cod_proceso := 66;
      else
        --limpiar variables
        v_cod_mon_credito := null;
        v_estado     := null;
        v_cod_modulo := null;
        v_cod_modalidad := null;
        v_cta_combinada := null;

        pag_cta.pr_obt_cuenta(reg.nro_cta_credito);
        if pag_cta.fu_obt_cod_error() <> 0 then
           v_concepto := substr(pag_cta.fu_obt_msj_error(),1,40);
           v_cod_proceso := 51;
        end if;
        v_cod_mon_credito := pag_cta.g_ctas.cod_moneda;
        v_estado     := pag_cta.g_ctas.estado;
        v_cod_modulo := pag_cta.G_CTAS.cod_modulo;
        v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
        v_cta_combinada := pag_cta.g_ctas.cta_combinada;
        --- si es cta ahorro o cta cte
         if v_cod_modalidad not in (31,41,334) THEN
            v_concepto     := 'MODALIDAD DE LA CUENTA INVALIDO';
            v_cod_proceso := 52;
         end if;
        if v_estado is null then
           v_concepto := 'ESTADO INVALIDO';
           v_cod_proceso := 53;
        end if;
       -- if v_cod_modalidad = 31 and v_cta_combinada = 'S' then
        --  v_concepto     := 'CUENTA COMBINADA P/AHORRO A LA VISTA';
         -- v_cod_proceso := 54;
        --end if;
        if v_estado IN ('C','T', 'P', 'X') THEN -- CR: se agrega pendiente de cancelación y verificación
          v_concepto     := 'ESTADO DE LA CUENTA INVALIDO';
          v_cod_proceso := 55;
        end if;
         if v_cod_moneda <> v_cod_mon_credito then
            -- Se elimina <> por caracter escapeado en homebanking ...
            v_concepto     := 'MONEDA CTA CREDITO INVALIDA';
            v_cod_proceso := 56;
         end if;
         --DDSI-7 - GD - OCT/2017
         --Valido la moneda de credito con la moneda de la cuenta de débito del ente
         if v_cod_moneda <> reg.cod_moneda then
            v_concepto     := 'MONEDA NO CORRESPONDE A LA CTA CREDITO';
            v_cod_proceso := 58;
         end if;

         -- CR: se verifica que la cuenta crédito no pertenezca al ente
         if v_cod_proceso = 0 and p_nro_cta_debito is not null then
           declare
             v_existe varchar2(1);
           begin
             select 'S'
               into v_existe
               from ge_cta_clientes cc, ge_entes ge
              where ge.cod_ente    = p_cod_ente
                and ge.cod_persona = cc.cod_persona
                and cc.nro_cuenta  = reg.nro_cta_credito;

             v_concepto    := 'CUENTA CREDITO PERTENECE AL ENTE';
             v_cod_proceso := 56;
           exception
             when others then
               v_existe := 'N';
           end;
         end if;
         --obtener principal de cuenta
         begin
           v_nom_persona := fue_obt_nom_persona(fug_obt_cli_principal(reg.nro_cta_credito));
         exception
           when others then
              if substr(sqlerrm,1,3)='ORA' then
                v_concepto  := substr(SQLERRM,12,40);
              ELSE
                v_concepto  := substr(SQLERRM,1,40);
              end if;
              v_cod_proceso :=57;
         end;
      END IF;--si tiene cta crédito
    end if; --- fin si forma de pago era en cta.crédito

  /*if reg.tip_comprobante not in ('F','O') then
      v_concepto := 'TIPO COMPROBANTE SOLO PUEDE SER F o O';
      v_cod_proceso := 59;
  end if;*/

    if reg.for_pago not in ('C','G','E','R','I') then
      v_concepto := 'FORMA DE PAGO INVALIDA';
      v_cod_proceso := 60;
    end if;

    if reg.for_pago = 'G' AND reg.beneficiario IS NULL THEN
      v_concepto := 'BENEFICIARIO NO EXISTE P/CHEQUE GERENCIA';
      v_cod_proceso := 61;
    end if;

    if reg.for_pago = 'C' AND reg.nro_cta_credito IS NULL THEN
      v_concepto := 'NO EXISTE CUENTA PARA EL CREDITO';
      v_cod_proceso := 61;
    end if;
    if reg.for_pago = 'I' then
       v_ind_valor := nvl(reg.ind_valor, 'B');
    else
       v_ind_valor := null;
    end if;

    -- MTOP Jun/2020 cambia a Bajo Valor - MT102 si ya cerro sipap SDSIPAP247-1
    if nvl(v_can_usd,0) >= 0 then -- si tiene registros en USD es directo Alto Valor
       v_ind_valor := 'A';
    else
      if v_ind_valor ='A' and paw_bas.fu_obt_tip_TransfInterbancaria(103,'001','002',302,reg.monto, reg.cod_moneda, null, fug_obt_cli_principal(p_nro_cta_debito) )='102' then
          v_ind_valor :='B';
      end if;
      v_cli_pue_enviar := fug_pue_env_tra_fue_hora(103,'001','002',302,reg.monto, reg.cod_moneda, null, p_nro_cta_debito);
    end if;
    --
    if reg.ben_dir_correo is not null and v_cod_proceso = 0 then
       if paw_uti.fu_validarMail(reg.ben_dir_correo) = 'N' then
          v_concepto := 'DIRECCION DE CORREO INVALIDO';
          v_cod_proceso := 79;
       end if;
    end if;
    if reg.for_pago = 'I' and v_cod_proceso = 0 then
      if nvl(v_hab_snp, 'N') = 'N' THEN
         v_concepto := 'CREDITO INTERBANCARIO INHABILITADO';
         v_cod_proceso := 61;
      elsif reg.cod_moneda is null then
         v_concepto := 'MONEDA CREDITO NO ESPECIFICADA';
         v_cod_proceso := 72;
      elsif reg.ind_valor = 'B' and reg.cod_moneda <> pag_gen.fu_obt_mon_local then
         v_concepto := 'PRIORIDAD INVALIDA, ACH SOLO PARA GS';
         v_cod_proceso := 72;
      elsif reg.monto > v_mto_max_ach and reg.ind_valor = 'B' then
         v_concepto := 'MONTO MAXIMO PARA ACH EXCEDIDO';
         v_cod_proceso := 64;
      elsif reg.cod_moneda <> v_cod_moneda and trunc(p_fec_pago1) > trunc(sysdate) then
            v_concepto := 'FECHA INVALIDA PARA OPERACION DE CAMBIO';
            v_cod_proceso := 76;
      elsif reg.cod_moneda <> v_cod_moneda and v_hor_snp_abierto = 'N' then
            v_concepto := 'HORA INVALIDA PARA OPERACION DE CAMBIO';
            v_cod_proceso := 76;
      --DDSI-7 - GD - OCT/2017
      elsif reg.cod_moneda <> v_cod_moneda and reg.nro_con_cambio is null then
            v_concepto := 'MONEDA DE CREDITO INVALIDA';
            v_cod_proceso := 72;
      elsif reg.nro_cta_beneficiario is null then
            v_concepto := 'NO EXISTE CUENTA INTERBANCARIA';
            v_cod_proceso := 66;
      elsif reg.nro_con_cambio is not null then
         declare
            v_mto_debito  lc_ope_pendientes.monto%TYPE;
            v_mto_credito lc_ope_pendientes.monto%TYPE;
         begin
            pr_val_nro_contrato(reg.nro_con_cambio,
                                fue_obt_per_ente(p_cod_ente),
                                reg.monto,
                                v_cod_moneda,
                                reg.cod_moneda,
                                v_ope_homebanking,
                                v_cod_proceso,
                                v_concepto,
                                v_mto_debito);
         end;
      elsif reg.cod_tip_doc_beneficiario is null then
         v_concepto := 'TIPO DOC. DEL BENEF. NO PUEDE SER NULO';
         v_cod_proceso := 74;
      elsif reg.nro_doc_beneficiario is null then
         v_concepto := 'DOCUMENTO DEL BENEF. NO PUEDE SER NULO';
         v_cod_proceso := 75;
      elsif reg.fec_pago - v_fec_actual > fug_obt_pardinamico('SNP_RAN_DIA_FEC_VALOR') then
         if reg.fec_pago != pag_cal.FU_OBT_FEC_HABIL(v_fec_actual + fug_obt_pardinamico('SNP_RAN_DIA_FEC_VALOR'), 1, v_cod_oficina) then
            v_concepto := 'FECHA DE PAGO ES MAYOR A '||fug_obt_pardinamico('SNP_RAN_DIA_FEC_VALOR')||' DIAS';
            v_cod_proceso := 76;
         end if;
      else
         -- verificamos si esta habilitado
         select count(*)
           into v_cant
           from gv_snp_participantes p
          where (p.cod_banco = reg.ent_bca_beneficiario or p.cod_ente = reg.ent_bca_beneficiario)
            and p.ind_hab_pte_hb = 'S'
            and p.cod_persona != fug_obt_per_entidad;
         if v_cant = 0 then
            v_concepto := 'ENTIDAD INEXISTENTE O INHABILITADA';
            v_cod_proceso := 78;
         else
           select count(0)
             into v_cant
             from ba_tip_documentos a
            where a.estado = 'A'
              and a.cod_tip_documento = reg.cod_tip_doc_beneficiario;
            if v_cant = 0 then
               v_concepto := 'TIPO DOC. DEL BENEF. INVALIDO';
               v_cod_proceso := 74;
            else
               if v_ind_valor = 'B' and reg.monto > v_mto_max_ach then--consultar con toppi ojo
                  v_ind_valor := 'A';
               end if;
            end if;
         end if;
      end if;
      -- DDSI-62 -- La prioridad de envío B (ACH) no está permitida para transferencias al BCP.
      if v_ind_valor = 'B' and reg.ent_bca_beneficiario = 1 then -- BCP
        v_concepto := 'PRIORIDAD ACH NO PERMITIDA PARA BCP';
        v_cod_proceso := 75;
      end if;
    end if;
    if v_cod_proceso = 0 then
       if reg.beneficiario is null then
          if reg.for_pago = 'C' then
             v_concepto := 'NO EXISTE BENEFICIARIO PARA EL CREDITO';
          else
             v_concepto := 'NO EXISTE BENEF. PARA EL CREDITO SIPAP';
          end if;
          v_cod_proceso := 77;
       end if;
    end if;
    --calcular fecha de pago
    v_fec_pago := fl_cal_fec_pago(reg.beneficiario, v_nom_persona);
    if p_error is not null then
      exit;
    end if;

    if reg.nro_orden is null then
    v_concepto     := 'NO TIENE ORDEN PAGO';
    v_cod_proceso := 62; ---- no tiene nro. orden pago
    end if;

    if reg.nro_factura is null then
     v_concepto     := 'NO TIENE NRO. FACTURA';
     v_cod_proceso := 63; ---- no tiene nro. factura
    end if;

    if nvl(reg.monto,0) = 0 then
      v_concepto     := 'NO TIENE MONTO A PAGAR';
      v_cod_proceso := 64; ---- no tiene monto a pagar
    end if;
    -- CR 03/09/2012
    if nvl(reg.monto,0) < 0 then
      v_concepto    := 'MONTO INVALIDO';
      v_cod_proceso := 64; ---- no tiene monto a pagar
    end if;
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,reg.cod_moneda);
    if nvl(reg.monto,0) <> trunc(nvl(reg.monto,0), v_redondeo) then
      v_concepto    := 'MONEDA NO ADMITE DECIMAL';
      v_cod_proceso := 64; ---- no tiene monto a pagar
    end if;
    --
    --Valido la moneda del txt con la moneda de la cuenta de débito del ente
    if reg.for_pago != 'I' and reg.cod_mon_recibido <> v_cod_moneda then
      v_concepto := 'MONEDA NO CORESPONDE A LA CTA. DE DEBITO';
      v_cod_proceso := 69;
    end if;
    -- Acá ya hace los controles por cada factura que lee...
    if v_tip_comprobante = 'O' and v_cod_proceso = 0 then
      v_tot_factura := 0;
      For reg_f in c_fac(reg.nro_orden) loop
        if reg_f.nro_orden is null then
           v_concepto := 'No tiene Nro.de orden en Facturas';
           v_cod_proceso := 65;
           --return;
        end if;
        if reg_f.nro_factura is null then
           v_concepto := 'No tiene Nro.Factura en el detalle';
           v_cod_proceso := 66;
        end if;
        if nvl(reg_f.mto_total,0) = 0 then
           v_concepto := 'No tiene Monto la Factura';
           v_cod_proceso := 67;
        end if;
        -- CR 03/09/2012
        if nvl(reg_f.mto_total,0) < 0 then
           v_concepto    := 'Monto Invalido';
           v_cod_proceso := 64; ---- no tiene monto a pagar
        end if;

        if nvl(reg_f.mto_total,0) <> trunc(nvl(reg_f.mto_total,0), v_redondeo) then
           v_concepto    := 'Moneda no Admite Decimal';
           v_cod_proceso := 64; ---- no tiene monto a pagar
        end if;
        --
        --
        v_tot_factura := v_tot_factura + nvl(reg_f.mto_total,0);
      end loop;
      if v_tot_factura <> nvl(reg.monto,0) and v_cod_proceso = 0 then
         v_concepto := 'No coincide monto de Orden con Facturas';
         v_cod_proceso := 68;
      end if;
    end if;
    -- OMM 04/05/2011 Verificamos si hay duplicación de comprobante
    v_can_duplicado := 0 ;
    if v_tip_comprobante = 'F' and v_cod_proceso = 0 then
       Select count(*) into v_can_duplicado
       from ge_pag_pro_facturas pf
       where pf.nro_orden = reg.nro_orden
         and pf.nro_factura = reg.nro_factura
         and pf.cod_ente = p_cod_ente;
       if v_can_duplicado > 0 then
           v_concepto := 'Orden ya ingresada Anteriormente';
           v_cod_proceso := 70;
        end if ;
    end if ;
    -- verifica si no hay duplicacion de datos temporales
    v_can_duplicado := 0 ;
    if v_tip_comprobante = 'F' and v_cod_proceso = 0 then
       select count(0)
         into v_can_duplicado
         from ge_pag_proveedores_tmp t
        where t.nro_orden = reg.nro_orden
          and t.nro_factura = reg.nro_factura
          and t.cod_ente = p_cod_ente
          and (nvl(t.nro_archivo, 0) <> nvl(reg.nro_archivo, 0) or
               (nvl(t.nro_archivo, 0) = nvl(reg.nro_archivo, 0) and t.nro_secuencia <> reg.nro_secuencia )
              )
          and trunc(t.fec_insercion) = nvl(v_fec_insercion,v_fec_actual);--trunc(sysdate);
       if v_can_duplicado > 0 then
           v_concepto := 'Registro ya ingresado Anteriormente';
           v_cod_proceso := 70;
        end if ;
    end if;

    ---- actualiza los datos que faltan en el tmp antes de pasar a GE_PAG_PROVEEDORES
    begin
       update ge_pag_proveedores_tmp set
           fec_ingreso        = nvl(v_fec_insercion,v_fec_actual),
           fec_pago           = decode(for_pago,'I', fec_pago, v_fec_pago),
           cod_proceso        = v_cod_proceso,
           concepto           = v_concepto,
           cod_moneda         = nvl(reg.cod_moneda,v_cod_moneda),
           referencia         = p_nro_documento,
           nro_cta_debito     = v_cta_debito,
           ind_valor          = v_ind_valor
        where current of c_tmp ;
        if sql%notfound then
          p_error := 'No encontro registro a actualizar en TMP de proveedores';
          exit;
        end if;
    exception
      when others then
         p_error := 'Al actualizar TMP de proveedores :'||sqlerrm;
         exit;
    end;
  end loop;
  if p_error is not null then
    return;
  end if;
  if v_tip_comprobante = 'O' then
    --* actualiza fecha de carga en tmp de facturas, SI ES QUE TIENE DETALLES
    begin
      update ge_pag_pro_facturas_tmp c
         set fec_carga  = (select fec_pago
                             from ge_pag_proveedores_tmp g
                            where g.nro_orden = c.nro_orden
                              and g.cod_ente = p_cod_ente
                              and nvl(g.nro_archivo, 0) = nvl(p_nro_archivo, 0)),
             cod_ente   = p_cod_ente
       where trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and usu_insercion = v_user
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

      if sql%notfound then
        p_error := 'No encontro registro a actualizar en TMP de facturas';
        return;
      end if;
    exception
      when others then
         p_error := 'Al actualizar TMP de facturas :'||sqlerrm;
         return;
    end;
   --solo si tiene detalles
    if v_tip_comprobante = 'O' then
      -- verifica datos del tmp de facturas
      /*v_tot_factura := 0;
      For reg in c_fac loop
        if reg.nro_orden is null then
           p_error := 'No tiene Nro.de orden en archivo de Facturas';
           return;
        end if;
        if reg.nro_factura is null then
           p_error := 'No tiene Nro.de factura en archivo de Facturas';
           return;
        end if;
        if reg.mto_total is null then
           p_error := 'No tiene Monto de factura en archivo de Facturas';
           return;
        end if;
      end loop;
*/
      -----Controles cruzados entre cabecera y detalle------
      select sum(nvl(mto_total,0))
        into v_todetal
        from ge_pag_pro_facturas_tmp
       where usu_insercion = v_user
         and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and cod_ente = p_cod_ente
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

      select sum(nvl(monto,0))
        into v_tocabec
        from ge_pag_proveedores_tmp
       where usu_insercion = v_user
         and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and cod_ente = p_cod_ente
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

      if v_todetal <> v_tocabec then
         p_error := 'El Total de Cabecera: '||v_tocabec||' no coincide con el Total del Detalle: '||v_todetal||'.';
         return;
      end if;
      v_cantidad := 0;
      select count(*)
        into v_cantidad
        from ge_pag_proveedores_tmp p
       where monto <> (select sum(nvl(mto_total,0))
                        from ge_pag_pro_facturas_tmp f
                        where p.nro_orden = f.nro_orden
                          and nvl(f.nro_archivo, 0) = nvl(p.nro_archivo, 0))
         and cod_ente = p_cod_ente
         and usu_insercion = v_user
         and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
      if nvl(v_cantidad,0) > 0 then
         p_error := 'Los Totales por Orden no coinciden.';
         return;
      end if;
      select count(*)
        into v_cantidad
        from ge_pag_pro_facturas_tmp
       where mto_total < 0
         and usu_insercion = v_user
         and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and cod_ente = p_cod_ente
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
      if nvl(v_cantidad,0) > 0 then
         p_error := 'Existen Facturas con Importes Negativos.';
         return;
      end if;

      SELECT COUNT(*)
        INTO v_cantidad
        FROM ge_pag_pro_facturas_tmp A
       WHERE EXISTS (SELECT 0 FROM ge_pag_pro_facturas B
                      WHERE A.nro_orden       = B.nro_orden
                        AND A.fec_carga       = B.fec_carga
                        AND A.cod_ente        = B.cod_ente
                        AND A.nro_factura     = B.nro_factura
                        AND A.mto_total       = B.mto_total
                        and A.concepto        = B.concepto);
      IF NVL(v_cantidad,0) > 0 THEN
        p_error := 'Los datos de Detalle ya estan en el Sistema. Verifique';
        return;
      END IF;
    end if;
  end if;

  -- CR: se comenta el commit
 /* if p_error is null then
    commit; --para q inserte en los tmp
  end if;*/

  -- ver si hubo error en los datos del tmp
  select count(*)
    into v_cant
    from ge_pag_proveedores_tmp
   where cod_proceso <> 0
     and usu_insercion = v_user
     and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
     and cod_ente = p_cod_ente
     and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

   if v_cant > 0 then
      p_error := 'Errores en la verificacion de datos.';
   else
      p_error := null;
   end if;

  --procesar si no tiene errores, cargar en las tablas definitivas
  if p_error is null and p_procesar = 'S' then
    --proceso
    PAG_PRV.PR_INS_GE_PAG_PROVEEDORES(p_cod_ente, nvl(v_fec_insercion,v_fec_actual),p_error, p_nro_archivo);
    if p_error is not null then
      return;
    end if;
    if v_tip_comprobante = 'O' then
      PAG_PRV.PR_INS_GE_PAG_PRO_FACTURAS(p_cod_ente, nvl(v_fec_insercion,v_fec_actual), p_error, p_nro_archivo);
    else
      --insertar el detalle igual q la cabecera, si es que no tiene detalles
      begin
        insert into ge_pag_pro_facturas
               (nro_orden, fec_carga, nro_factura, mto_total, concepto,  cod_ente )
        select nro_orden, fec_ingreso, nro_factura, monto, concepto, cod_ente
          from ge_pag_proveedores_tmp
         where cod_ente = p_cod_ente
           and usu_insercion = user
           and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
           and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
      exception
        when others then
           p_error := 'Error al actualizar detalles '||sqlerrm;
      end;
    end if;
    if p_error is not null then
      return;
    end if;
  end if;
exception
   when others then
      if sqlcode <= -20000 then
        raise;
      else
        raise_application_error (-20000,'Verif.Datos Pag.Prov. '||sqlerrm);
      end if;
end PR_VER_DAT_TMP;


/*verifica los datos del tmp y procesa si no hay errores*/
PROCEDURE PR_VER_DAT_TEMPORALES
(p_cod_ente in ge_entes.cod_ente%type,
 p_fec_pago1 in date,
 p_error out varchar2,
 p_procesar in varchar2) IS

  v_cod_proceso     number(3) := 0;
  v_cant            number(5);
  v_cantidad        number(10);
  v_cod_modulo      ge_transacciones.cod_modulo%type;
  v_cod_modalidad   ge_transacciones.cod_modalidad%type;
  v_cod_moneda      ah_cta_vistas.cod_moneda%type;
  v_nro_cuenta      ge_cuentas.nro_cuenta%type;
  v_cta_combinada   ah_cta_vistas.cta_combinada%type;
  v_estado          ah_cta_vistas.estado%type;
  v_cod_mon_credito ah_cta_vistas.cod_moneda%type;
  v_concepto         ge_pag_proveedores_tmp.concepto%type;
  v_fec_pago         date;
  v_nombre           varchar2(50);
  v_fec_actual       ge_calendarios.fec_actual%type := trunc(sysdate);--pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_descripcion      ge_entes.descripcion%type;
  v_tip_comprobante  ge_pag_proveedores.tip_comprobante%type;
  v_cod_tra_padre    ge_transacciones.cod_transaccion%type;
  v_cta_debito       ge_cuentas.nro_cuenta%type;
  v_cod_rubro        cb_rubros.cod_rubro%type;
  v_pag_atrasada     ge_pag_proveedores.tip_carga%type;
  v_ref_archivo      ge_archivos.referencia%type;
  v_cod_tra_debito   ge_transacciones.cod_transaccion%type;
  v_todetal  number(18,2);
  v_tocabec  number(18,2);
  v_cod_oficina      ba_oficinas.cod_oficina%type;
  v_existe           varchar2(1) := 'N';
  v_nom_persona      ba_personas.nom_completo%type;
  v_tot_factura      number(18,2);
  v_Exi_Cta          number;
  v_exi_cta_deb      number;
  v_sum_monto        number;
  v_ind_valor        varchar2(1);

  cursor c_tmp is
    select *
      from ge_pag_proveedores_tmp
     where trunc(fec_insercion) = v_fec_actual
       and usu_insercion = user
       and cod_ente = p_cod_ente
       and nvl(tipo,'C') = 'C'
    order by nro_Secuencia
   for update;
/* principal */
BEGIN
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  --recupera oficina del usuario
  begin
    select cod_oficina
      into v_cod_oficina
      from ba_usuarios
     where cod_usuario = user;
  exception
    when others then
      p_error := 'Recup.oficina del usuario '||sqlerrm;
      return;
  end;
  --recupera parametros del ente.
  pag_prv.PR_OBT_DAT_PROVEEDOR(p_cod_ente, v_descripcion, v_tip_comprobante, v_cod_tra_padre, v_cta_debito,
                              v_pag_atrasada, v_ref_archivo, v_cod_tra_debito,v_cod_rubro);

  --actualiza los datos basicos del tmp para poder verificar, solo si no actualizo antes
  begin
     update ge_pag_proveedores_tmp set
         tip_comprobante    = v_tip_comprobante,
         estado             = 'C',        --- cargado
         cod_usu_operador   = user,
         cod_ente           = p_cod_ente,
         tip_carga          = decode(nvl(PAE_CNF.G_PROGRAMA,'X'),'X','H','A')
      where trunc(fec_insercion) = v_fec_actual
       and usu_insercion = user --por el usuario
       and (cod_ente = p_cod_ente or cod_ente is null);
  exception
     when others then
        p_error := 'Actualizar TMP de proveedores.'||sqlerrm;
        return;
  end;

  -- Verifico si no se realizo el mismo pago en la misma fecha
  Declare
   cursor c_deb is
    Select t.nro_cta_Debito, sum(monto) monto
      from ge_pag_proveedores_tmp t
     where cod_ente = p_cod_ente
       and trunc(fec_insercion) = v_Fec_actual
       and tipo = 'C'
    group by nro_Cta_debito;
  Begin
   For reg in c_deb loop
      Select sum(monto) into v_sum_monto
        from ge_pag_proveedores p
       where p.cod_ente = p_cod_ente
         and p.fec_pago = p_fec_pago1
         and p.nro_cta_debito = reg.nro_Cta_debito;
      if  v_sum_monto = reg.monto then
         p_error := 'Ya se realizo este pago en la fecha.';
         return;
      end if;
    end loop;
   End;

   -- Verifico parametrización si está habilitado SIPAP
   select count(*)
     into v_cant
     from ge_pag_proveedores_tmp
    where trunc(fec_insercion) = v_fec_actual
      and usu_insercion = user
      and cod_ente = p_cod_ente
      and nvl(tipo,'C') = 'C'
      and for_pago = 'I';
   if v_cant > 0
     and fug_obt_parentes(p_cod_ente, 'SNP_HAB_PROVEEDORES') != 'S' then
      p_error := 'Ente no se encuentra habilitado para operar con SIPAP.';
      return;
   end if;

   -- Verifico que no existan lotes mixtos en horario cerrado SIPAP
   select count(*)
     into v_cant
     from(select decode(for_pago, 'I', 'I', 'X')
            from ge_pag_proveedores_tmp
           where trunc(fec_insercion) = v_fec_actual
             and usu_insercion = user
             and cod_ente = p_cod_ente
             and nvl(tipo,'C') = 'C'
           group by decode(for_pago, 'I', 'I', 'X'));

   if v_cant = 2 then--Mixto (interbancaria y otro)
      --hallar horario
      IF lf_obt_hor_snp = 'N' THEN
         v_cant := 0;
      END IF;
      /*select count(*)
        into v_cant
        from ge_snp_horarios b
       where b.estado = 'A'
         and exists (select 1
                       from ge_snp_par_mensajes a
                      where a.cod_msj_swift in (102, 103)
                        and b.cod_periodo in (a.cod_periodo,
                                              a.cod_periodo2,
                                              a.cod_periodo3));*/
      if v_cant = 0 then
         p_error := 'Horario SIPAP Cerrado, no se puede procesar archivo Mixto';
         return;
      end if;
   end if;

  -- Verifico la cuenta de debito
  select count(*) into v_exi_cta_deb
    from ge_pag_proveedores_tmp
   where tipo = 'D';
  If  v_exi_cta_deb <> 0 then   --- Archivo con cuentas debito
   Declare
    Cursor c_cta_Deb is
      select distinct nro_Cta_debito
        from ge_pag_proveedores_tmp
      where trunc(fec_insercion) = v_fec_actual
        and usu_insercion = user
        and cod_ente = p_cod_ente
        and nro_Cta_debito is not null;
    Begin
      For reg in c_cta_deb loop
        PR_VER_CTA_DEBITO(reg.nro_Cta_debito, p_Error);
        if  p_error is not null then
          return;
        end if;
      End loop;
    End;
  else  --- Archivo sin cuentas debito, se toma el del parametro
     PR_VER_CTA_DEBITO(v_cta_debito, p_Error);
     if  p_error is not null then
       return;
     end if;
  end if;
  v_cod_moneda := pag_cta.g_ctas.cod_moneda;
  v_estado     := pag_cta.g_ctas.estado;
  v_cod_modulo := pag_cta.G_CTAS.cod_modulo;
  v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
  v_cta_combinada := pag_cta.g_ctas.cta_combinada;

  --recorre los registros del temporal para verificar datos: cta.credito, forma de pago , etc
  for reg in c_tmp loop
    v_existe := 'S';
    exit;
  end loop;
  if v_existe is null then
    p_error := 'No existen datos cargados en el tmp. Verifique';
    return;
  end if;

  --recorre los registros del temporal para verificar datos: cta.credito, forma de pago , etc
  for reg in c_tmp loop
    v_concepto     := nvl(reg.concepto, 'Pago Proveedor '||reg.nro_factura);  -- 03/2016--
    v_cod_proceso := 0;
    -- Validar que no se procese un pago con fecha anterior.
    if reg.fec_pago < pag_cal.FU_OBT_FEC_ACTUAL(1) then
       v_concepto := 'FECHA DE PAGO MENOR A LA ACTUAL';
       v_cod_proceso := 65;
    end if;
    -- Verifico la cuenta de credito
    if reg.for_pago = 'C' THEN -- credito en cuenta
      if reg.nro_Cta_credito IS NULL THEN
         v_concepto := 'NO EXISTE CUENTA PARA EL CREDITO';
         v_cod_proceso := 66;
      else
        --limpiar variables
        v_cod_mon_credito := null;
        v_estado     := null;
        v_cod_modulo := null;
        v_cod_modalidad := null;
        v_cta_combinada := null;

        pag_cta.pr_obt_cuenta(reg.nro_cta_credito);
        if pag_cta.fu_obt_cod_error() <> 0 then
           v_concepto := substr(pag_cta.fu_obt_msj_error(),1,40);
           v_cod_proceso := 51;
        end if;
        select count(*) into v_exi_cta
          from ge_cuentas
         where nro_cuenta = reg.nro_Cta_Credito;
        if  v_exi_Cta = 0 then
           v_concepto := 'CUENTA NO EXISTE EN GE_CUENTAS';
           v_cod_proceso := 51;
        end if;
        v_cod_mon_credito := pag_cta.g_ctas.cod_moneda;
        v_estado     := pag_cta.g_ctas.estado;
        v_cod_modulo := pag_cta.G_CTAS.cod_modulo;
        v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
        v_cta_combinada := pag_cta.g_ctas.cta_combinada;
        --- si es cta ahorro o cta cte
         if v_cod_modalidad not in (31,41,334) THEN
            v_concepto     := 'MODALIDAD DE LA CUENTA INVALIDO';
            v_cod_proceso := 52;
         end if;
        if v_estado is null then
           v_concepto := 'ESTADO INVALIDO';
           v_cod_proceso := 53;
        end if;
        if v_estado IN ('C','T','P','X') THEN
          v_concepto     := 'ESTADO DE LA CUENTA INVALIDO';
          v_cod_proceso := 55;
        end if;
         if v_cod_moneda <> v_cod_mon_credito then
            -- Se elimina <> por caracter escapeado en homebanking ...
            v_concepto     := 'MONEDA CTA CREDITO INVALIDA';
            v_cod_proceso := 56;
         end if;
         --obtener principal de cuenta
         begin
           v_nom_persona := fue_obt_nom_persona(fug_obt_cli_principal(reg.nro_cta_credito));
         exception
           when others then
              if substr(sqlerrm,1,3)='ORA' then
                v_concepto  := substr(SQLERRM,12,40);
              ELSE
                v_concepto  := substr(SQLERRM,1,40);
              end if;
              v_cod_proceso :=57;
         end;
      END IF;--si tiene cta credito
    end if; --- fin si forma de pago era en cta.credito

    if reg.for_pago not in ('C','G','E','R','I') then
      v_concepto := 'FORMA DE PAGO INVALIDA';
      v_cod_proceso := 60;
    end if;

    if reg.for_pago = 'G' AND reg.beneficiario IS NULL THEN
      v_concepto := 'BENEFICIARIO NO EXISTE P/CHEQUE GERENCIA';
      v_cod_proceso := 61;
    end if;

    if reg.for_pago = 'C' AND reg.nro_cta_credito IS NULL THEN
      v_concepto := 'NO EXISTE CUENTA PARA EL CREDITO';
      v_cod_proceso := 61;
    end if;

    --calcular fecha de pago
    v_fec_pago := pag_cal.FU_OBT_FEC_HABIL(p_fec_pago1, 1, v_cod_oficina);
    if p_error is not null then
      exit;
    end if;

    if reg.nro_orden is null then
    v_concepto     := 'NO TIENE ORDEN PAGO';
    v_cod_proceso := 62; ---- no tiene nro. orden pago
    end if;

    if nvl(reg.monto,0) = 0 then
      v_concepto     := 'NO TIENE MONTO A PAGAR';
      v_cod_proceso := 64; ---- no tiene monto a pagar
    end if;
    --Valido la moneda del txt con la moneda de la cuenta de debito del ente
    if reg.for_pago != 'I' and reg.cod_mon_recibido <> v_cod_moneda then
      v_concepto := 'MONEDA NO CORESPONDE A LA CTA. DE DEBITO';
      v_cod_proceso := 69;
    end if;
    --Validaciones Interbancarias
    if reg.for_pago = 'I' then
       --Validación contrato de cambios
       if reg.nro_con_cambio is not null then
          select count(*)
            into v_cant
            from lc_ope_pendientes l
           where l.liquidado    = 'N'
            and l.nro_operacion = nvl(reg.nro_con_cambio,l.nro_operacion);

          if v_cant = 0 then
             v_concepto := 'NO EXISTE CONTRATO DE CAMBIOS.';
             v_cod_proceso := 73;
          end if;
       end if;
       v_cant:=0;
         -- verificamos si esta habilitado
         select count(*)
           into v_cant
           from gv_snp_participantes p
          where (p.cod_banco = reg.ent_bca_beneficiario or p.cod_ente = reg.ent_bca_beneficiario)
            and p.ind_hab_pte_hb = 'S';
       if v_cant = 0 then
            v_concepto := 'ENTIDAD INEXISTENTE O INHABILITADA';
            v_cod_proceso := 78;
       end if;

       --Verifica que los datos del beneficiario esten completos.
       if reg.cod_tip_doc_beneficiario is null
        /*or reg.nro_cta_beneficiario is null*/ then
          v_concepto := 'TIPO DOC. DEL BENEF. NO PUEDE SER NULO';
          v_cod_proceso := 70;
       elsif reg.nro_doc_beneficiario is null then
         v_concepto := 'DOCUMENTO DEL BENEF. NO PUEDE SER NULO';
          v_cod_proceso := 70;
       else
       --Valido la entidad beneficiaria
       --DYDMR-6468 04/2017 GDF
          select count(*)
            into v_cant
            from gv_snp_participantes p
           where (p.cod_banco = reg.ent_bca_beneficiario or
                 p.cod_ente = reg.ent_bca_beneficiario)
             and cod_persona != fug_obt_per_entidad;
          if v_cant = 0 then
            v_concepto := 'ENTIDAD INTERBANCARIA '||reg.ent_bca_beneficiario||' NO EXISTE';
            v_cod_proceso := 71;
          end if;
          --Valido el indicador de alto valor
          v_ind_valor := nvl(reg.ind_valor, 'B');
          if v_ind_valor = 'B'
            and reg.monto > nvl(fug_obt_pardinamico('MTO_MAX_ACH'), 0) then--consultar con toppi ojo
            v_ind_valor := 'A';
          end if;
          --Valido la fecha de Pago
          if reg.fec_pago - v_fec_actual > fug_obt_pardinamico('SNP_RAN_DIA_FEC_VALOR') then
             v_concepto := 'FECHA DE PAGO ES MAYOR A '||fug_obt_pardinamico('SNP_RAN_DIA_FEC_VALOR')||' DIAS';
             v_cod_proceso := 72;
          end if;
       end if;
    end if;

    ---- actualiza los datos que faltan en el tmp antes de pasar a GE_PAG_PROVEEDORES
    begin
       update ge_pag_proveedores_tmp set
           fec_ingreso        = v_fec_actual,
           fec_pago           = decode(for_pago,'I', fec_pago, v_fec_pago),
           cod_proceso        = v_cod_proceso,
           concepto           = v_concepto,
           cod_moneda         = nvl(reg.cod_moneda,v_cod_mon_credito),
           ind_valor          = v_ind_valor
        where current of c_tmp ;
        if sql%notfound then
          p_error := 'No encontro registro a actualizar en TMP de proveedores';
          exit;
        end if;
    exception
      when others then
         p_error := 'Al actualizar TMP de proveedores :'||sqlerrm;
         exit;
    end;
  end loop;
  --Verifica que se hayan procesado datos
  if nvl(v_existe, 'N') = 'N' then
    p_error := 'No existen datos cargados en el tmp. Verifique';
    return;
  end if;
  -- ver si hubo error en los datos del tmp
  select count(*)
    into v_cant
    from ge_pag_proveedores_tmp
   where cod_proceso <> 0
     and usu_insercion = user
     and trunc(fec_insercion) = v_fec_actual
     and cod_ente = p_cod_ente
     and NVL(tipo,'C') = 'C';

   if v_cant > 0 then
      p_error := 'Errores en la verificacion de datos.';
   else
      p_error := null;
   end if;

  --procesar si no tiene errores, cargar en las tablas definitivas
  if p_error is null and p_procesar = 'S' then
    --proceso
    PAG_PRV.PR_INS_GE_PAG_PROVEEDORES(p_cod_ente, v_fec_actual, p_error);
    if p_error is not null then
      return;
    end if;
  end if;
exception
   when others then
      if sqlcode <= -20000 then
        raise;
      else
        raise_application_error (-20000,'Verif.Datos Pag.Prov2. '||sqlerrm);
      end if;
end PR_VER_DAT_TEMPORALES;

/* valida el formato de hora de cierre de pago a proveedores (hh24:mi) */
PROCEDURE PR_VER_FMT_HOR_CIERRE(p_hor_cierre in ge_par_dinamicos.val_parametro%type) IS
v_hor_cierre ge_par_dinamicos.val_parametro%type := trim(p_hor_cierre);
v_hora      number(2);
v_minuto    number(2);
v_separador varchar2(1);
v_msj_error varchar2(50);
v_error     boolean := false;
BEGIN
  if length(v_hor_cierre) <> 5 then
    v_msj_error := 'Favor ingrese en formato hh24:mi';
    v_error := true;
  else
    begin
      v_hora      := to_number(substr(v_hor_cierre, 1, 2));
      v_minuto    := to_number(substr(v_hor_cierre, 4, 2));
      v_separador := substr(v_hor_cierre, 3, 1);

      if v_minuto < 0 or v_minuto > 59 then
        v_msj_error := 'Favor ingrese en formato hh24:mi. Minuto Invalido';
        v_error := true;
      elsif v_hora < 0 or v_hora > 23 then
        v_msj_error := 'Favor ingrese en formato hh24:mi. Hora Invalida';
        v_error := true;
      elsif v_separador <> ':' then
        v_msj_error := 'Favor ingrese en formato hh24:mi.';
        v_error := true;
      end if;
    exception
      when others then
        v_msj_error := 'Favor ingrese en formato hh24:mi';
        v_error := true;
    end;
  end if;

  if v_error then
    raise_application_error(-20000, v_msj_error);
  end if;
END;

/*Genera la retencion de los proveedores de la empresa y devuelve el valor de la retencion*/
PROCEDURE PR_GEN_RETENCION(
v_cod_ente in number, v_cod_proveedor in number,v_nro_factura in varchar2,
v_fec_pago in date, v_procesa out varchar2, v_monto_retencion out number) is
v_retentor  varchar2(1);
v_retencion varchar2(40);
v_secuencia number(38);
v_importe   number(18,2);
v_monto_iva number(18,2);
v_mto_retencion number(18,2);
v_cod_moneda   varchar2(3);
v_cotizacion ge_movimientos.cotizacion%type;
v_nro_timbrado     ge_ret_proveedores.nro_timbrado%type;
v_fec_vig_timbrado ge_ret_proveedores.fec_vig_timbrado%type;
v_cod_ofi_hacienda ba_oficinas.cod_oficina%type;
v_pun_expedicion   number(3);
v_act_ret_irp varchar2(1):= fug_obt_pardinamico('RET_IMP_IRP_ACTIVO',null,null,null);
v_ret_irp   varchar2(1);
v_por_ret_irp varchar2(40);
v_mto_renta number(18,2):=0;
v_mto_ret_renta number(18,2):=0;
begin

   --Para saber si se le retiene o no el iva al proveedor
   select val_parametro into v_retentor
   from ge_par_entes where parametro= 'CON_RETENCION'
   and cod_ente= v_cod_proveedor;

   if v_act_ret_irp = 'S' then -- Solo si está activa la funcionalidad de IRP.
      --Para saber si se le retiene por IRP al proveedor
      Begin
        select SUBSTR(val_parametro,1,1) into v_ret_irp
          from ge_par_entes where parametro= 'CON_RET_IRP'
           and cod_ente= v_cod_proveedor;
       Exception
         When others then
            v_ret_irp := 'N';
       End;
   end if;

   if v_retentor = 'S' or (v_act_ret_irp = 'S' and v_ret_irp = 'S') then

      --El valor del iva a descontar
      v_retencion:= fug_obt_pardinamico('POR_RET_PROVEEDOR');

      BEGIN
       select
       a.monto ,a.cod_moneda,
         nvl(prov.tot_impuesto,0) monto_iva,
         round(( nvl(prov.tot_impuesto,0) * (v_retencion/100) ),fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,a.cod_moneda,null)) monto_retencion
         into v_importe, v_cod_moneda, v_monto_iva,v_mto_retencion
         from ge_pag_proveedores a,  pv_compras prov
         WHERE a.cod_ente = v_cod_ente
         and prov.nro_factura = a.nro_factura
         and prov.nom_proveedor = a.beneficiario
         and  a.nro_factura= v_nro_factura
         and  prov.cod_ent_proveedor = v_cod_proveedor
         AND a.estado IN ('C','R') -- CB. 11/11/2013. SPI 2751.
         AND prov.estado NOT IN ('N','P') -- CB. 11/11/2013. SPI 2751.
         and not exists (select 1 from ge_ret_proveedores where nro_factura = v_nro_factura and cod_proveedor = v_cod_proveedor and estado = 'N' and fec_pago = v_fec_pago);
          v_monto_retencion:= v_mto_retencion;
          v_cotizacion := pag_gen.fu_obt_cotizacion( v_cod_moneda, pag_cal.fu_obt_fec_actual(1) );
      EXCEPTION
       WHEN NO_DATA_FOUND THEN
           v_procesa := 'N';
       WHEN OTHERS THEN
           v_procesa := sqlerrm;--'N';
      END;
      --es para la secuencia de la tabla de retencion
      --v_secuencia:= fug_obt_pardinamico('SIG_NRO_RETENCION')+1;
      /*
      || RABF 12/mar/2011
      || se llavea el pardinámico
      || para no duplicar comprobantes de retención
      */
      --v_secuencia:= fug_obt_lla_pardinamico('SIG_NRO_RETENCION')+1;
      --Obtiene el numero de retención, timbrado y fecha de vigencia del timbrado
      v_cod_ofi_hacienda := fug_obt_pardinamico('COD_OFI_HACIENDA', null, null, null, fug_obt_ofi_matriz());
      if v_cod_ofi_hacienda is null then
        raise_application_error(-20000, 'No se ha definido el parametro COD_OFI_HACIENDA para la oficina '||fug_obt_ofi_matriz());
      end if;
      --v_pun_expedicion   := pab_iva.fu_obt_pun_expedicion('R');
      pab_iva.pr_obt_nro_factura(v_cod_ofi_hacienda, pag_cal.fu_obt_fec_actual(1), 'R', v_secuencia, v_nro_timbrado, v_fec_vig_timbrado);--La numeracion es unica para todas las oficinas
      --v_secuencia := v_cod_ofi_hacienda || lpad(v_pun_expedicion,3,'0')|| lpad(to_char(v_secuencia),7,'0');
      v_secuencia:= fug_obt_lla_pardinamico('SIG_NRO_RETENCION')+1;
      --
      /*Calculo del IRP */
      if v_act_ret_irp = 'S' and v_ret_irp = 'S' then
         -- Porcenateje de retencion IRP
         v_por_ret_irp := nvl(fug_obt_parentes(v_cod_proveedor,'POR_RET_IRP'),fug_obt_pardinamico('POR_RET_IRP_PROVEEDOR'));
         -- Obtiene el monto gravado
         v_mto_renta := round((v_importe / 1.1 ),fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_moneda,null));
         -- Obtiene el monto de la retencion del IRP
         v_mto_ret_renta := round(v_mto_renta*(v_por_ret_irp/100),fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_moneda,null));
         -- Suma el monto de la retencion de IRP al monto de retencion del IVA.
         v_monto_retencion:= v_mto_retencion + v_mto_ret_renta;
      end if;
      /*Si el proveedor no se le retiene IVA - vuelve a cerar los importes por Retencion de IVA*/
      if v_retentor = 'N' then
         v_monto_iva := 0;
         v_mto_retencion := 0;
      end if;

      insert into ge_ret_proveedores
         (cod_proveedor, fec_pago, nro_factura, importe, cod_moneda, nro_retencion, monto_iva, monto_retencion, estado, cotizacion, mto_renta, mto_ret_renta, nro_timbrado, fec_vig_timbrado)
      values(v_cod_proveedor,
             v_fec_pago,
             v_nro_factura,
             v_importe,
             v_cod_moneda,
             v_secuencia,
             v_monto_iva,
             v_mto_retencion,
             'N'/*estado= pagado*/,
             v_cotizacion,
             v_mto_renta,
             v_mto_ret_renta,
             v_nro_timbrado,
             v_fec_vig_timbrado);
      --commit; Se comenta ya que no debe hacer un commit intermedio
      begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
      --para actualizar la secuencia
      prg_act_par_dinamico('SIG_NRO_RETENCION',null,null, null, null, v_secuencia);

   end if;


end PR_GEN_RETENCION;
/* Proceso para el cobro de comisiones */
PROCEDURE PR_COB_COMISION(p_cod_comision in varchar2,
                          p_des_comision in varchar2,
                          p_cod_ente in ge_entes.cod_ente%type,
                          p_cod_tra_padre in ge_movimientos.cod_tra_padre%type,
                          p_nro_cta_debito in ge_movimientos.nro_cuenta%type,
                          p_cod_modulo in ge_movimientos.cod_modulo%type,
                          p_cod_modalidad in ge_movimientos.cod_modalidad%type,
                          p_cod_moneda in ge_movimientos.cod_moneda%type,
                          p_monto in ge_movimientos.monto%type,
                          p_cod_oficina in ge_movimientos.cod_oficina%type,
                          p_can_credito in number,
                          p_nro_documento in ge_movimientos.nro_documento%type,
                          p_fecha in ge_movimientos.fecha%type,
                          p_hora in ge_movimientos.hora%type,
                          p_nro_secuencia in out ge_movimientos.nro_secuencia%type,
                          p_error in out varchar2,
                          p_msj_error in out varchar2,
                          p_mov_pendiente varchar2 default 'N') IS
-- código de la comisión recibida
v_cod_tra_comision   ge_movimientos.cod_transaccion%type;
  -- procedimiento interno para hacer el débito correspondiente
  PROCEDURE lp_act_ope_debito(p_fecha in date,
                              p_hora in varchar2,
                              p_nro_cuenta in ge_cuentas.nro_cuenta%type,
                              p_cod_transaccion in ge_movimientos.cod_transaccion%type,
                              p_cod_tra_padre in ge_movimientos.cod_tra_padre%type,
                              p_concepto in ge_movimientos.concepto%type,
                              p_cod_ofi_origen in ge_cuentas.cod_oficina%type,
                              p_cod_mod_padre in ge_cuentas.cod_modulo%type,
                              p_cod_mad_padre in ge_cuentas.cod_modalidad%type,
                              p_cod_tasa in ge_movimientos.cod_tasa%type,
                              p_val_tasa in ge_movimientos.val_tasa%type,
                              p_monto in ge_movimientos.val_tasa%type,
                              p_nro_secuencia in out ge_movimientos.nro_secuencia%type,
                              p_error in out varchar2,
                              p_msj_error in out varchar2) IS

  v_cod_modulo         ba_modulos.cod_modulo%type;
  v_cod_modalidad      ge_modalidades.cod_modalidad%type;
  v_estado             ge_cuentas.estado%type;
  v_procesa            varchar2(1) := 'N';
  v_sal_disponible     ge_movimientos.monto%type;
  rv_gmpe              ge_mov_pendientes%rowtype := null;

  BEGIN
    -- se verifica si se puede debitar la comisión
    pag_cta.pr_ver_operacion(p_nro_cuenta,
                             p_cod_tra_padre,
                             p_cod_mod_padre,
                             p_cod_mad_padre,
                             'D',
                             p_cod_moneda,
                             p_monto,
                             p_cod_ofi_origen,
                             v_cod_modulo,
                             v_cod_modalidad,
                             v_estado,
                             v_sal_disponible,
                             v_procesa,
                             p_cod_transaccion);

    IF v_procesa = 'N' THEN
      IF p_mov_pendiente = 'S' AND v_sal_disponible < p_monto AND pag_cta.g_ctas.estado <> 'I' THEN
        rv_gmpe.nro_cuenta      := p_nro_cuenta;
        rv_gmpe.fecha           := p_fecha;
        rv_gmpe.cod_modulo      := v_cod_modulo;
        rv_gmpe.cod_modalidad   := v_cod_modalidad;
        rv_gmpe.cod_transaccion := p_cod_transaccion;
        rv_gmpe.cod_mod_padre   := p_cod_mod_padre;
        rv_gmpe.cod_mad_padre   := p_cod_mad_padre;
        rv_gmpe.cod_tra_padre   := p_cod_tra_padre;
        rv_gmpe.monto           := p_monto;
        rv_gmpe.hora            := p_hora;
        rv_gmpe.cod_usuario     := user;
        rv_gmpe.cod_moneda      := p_cod_moneda;
        rv_gmpe.cod_oficina     := p_cod_oficina;
        rv_gmpe.cod_error       := pag_cta.g_cod_error;
        rv_gmpe.estado          := 'I';
        rv_gmpe.cod_ofi_origen  := p_cod_ofi_origen;
        rv_gmpe.concepto        := p_des_comision;
        rv_gmpe.cod_tasa        := p_cod_tasa;
        rv_gmpe.val_tasa        := p_val_tasa;
        rv_gmpe.nro_documento   := p_nro_documento;
        rv_gmpe.saldo           := p_monto;
        rv_gmpe.motivo          := pag_cta.g_msj_error;
        rv_gmpe.car_manual      := 'N';

        insert into ge_mov_pendientes values rv_gmpe;
      ELSE
        p_error := '07';
        p_msj_error := 'Error con Cta Debito '||p_nro_cuenta||'-'||pag_cta.fu_obt_msj_error;
      END IF;
    ELSE
      -- se realiza la operación
      pag_cta.pr_act_operacion(p_nro_cuenta,
                               p_hora,
                               'D',
                               p_cod_moneda,
                               p_monto,
                               p_cod_tra_padre,
                               p_cod_transaccion,
                               p_nro_documento,
                               NULL,
                               p_cod_oficina,
                               p_cod_modulo,
                               p_cod_modalidad,
                               p_cod_tasa,
                               p_val_tasa,
                               p_concepto,
                               'S',
                               p_nro_secuencia,
                               p_fecha);
      -- controlamos si no hubo error
      IF pag_cta.fu_obt_cod_error() <> 0 THEN
        p_error := '09';
        p_msj_error := 'Error al Tratar de Procesar Debito. '||pag_cta.fu_obt_msj_error;
      END IF;
    END IF;
  END lp_act_ope_debito;

  -- procedimiento interno para calcular la comisión y realizar el débito
  PROCEDURE lp_cob_comision(p_cod_tra_comision in ge_movimientos.cod_transaccion%type,
                            p_con_comision in varchar2,
                            p_can_registro in number,
                            p_nro_secuencia in out ge_movimientos.nro_secuencia%type,
                            p_error in out varchar2,
                            p_msj_error in out varchar2) IS
  v_cod_tas_comision   ge_movimientos.cod_tasa%type;
  v_val_comision       ge_movimientos.val_tasa%type;
  v_comision           ge_movimientos.val_tasa%type;
  v_cod_tra_impuesto   ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto   ge_movimientos.cod_tasa%type;
  v_val_iva            ge_movimientos.val_tasa%type;
  v_iva                ge_movimientos.val_tasa%type;
  BEGIN
    -- si hubo error, no se debe realziar ninguna operación
    IF p_error <> '00' THEN
      RETURN;
    END IF;

    PRG_OBT_CARGOS(p_cod_oficina,        --P_COD_OFI_ORIGEN    IN GE_CUENTAS.COD_OFICINA%TYPE
                   p_nro_cta_debito,     --P_NRO_CUENTA        IN GE_CUENTAS.NRO_CUENTA%TYPE
                   p_cod_moneda,         --P_COD_MONEDA        IN GE_CUENTAS.COD_MONEDA%TYPE
                   p_monto,              --P_MONTO             IN GE_MOVIMIENTOS.MONTO%TYPE
                   p_cod_modulo,         --P_COD_MODULO        IN GE_CUENTAS.COD_MODULO%TYPE
                   p_cod_modalidad,      --P_COD_MODALIDAD     IN GE_CUENTAS.COD_MODALIDAD%TYPE
                   p_cod_tra_comision,   --P_COD_TRA_CARGO     IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
                   v_cod_tas_comision,   --P_COD_TAS_CARGO     OUT GE_MOVIMIENTOS.COD_TASA%TYPE
                   v_val_comision,       --P_VAL_TAS_CARGO     OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                   v_comision,           --P_VAL_CARGO         OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                   v_cod_tra_impuesto,   --P_COD_TRA_IMPUESTO  OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
                   v_cod_tas_impuesto,   --P_COD_TAS_IMPUESTO  OUT GE_MOVIMIENTOS.COD_TASA%TYPE
                   v_val_iva,            --P_VAL_TAS_IMPUESTO  OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                   v_iva );             -- P_VAL_IMPUESTO      OUT GE_MOVIMIENTOS.VAL_TASA%TYPE

    v_comision := nvl(v_comision, 0) * p_can_registro;
    v_iva      := nvl(v_iva, 0) * p_can_registro;

    -- se realiza el débito de la comisión
    IF v_comision > 0 THEN
      lp_act_ope_debito(p_fecha,              -- p_fecha
                        p_hora,               -- p_hora
                        p_nro_cta_debito,     -- p_nro_cuenta
                        p_cod_tra_comision,   -- p_cod_transaccion
                        p_cod_tra_padre,      -- p_cod_tra_padre
                        p_con_comision,       -- p_concepto
                        p_cod_oficina,        -- p_cod_ofi_origen
                        p_cod_modulo,         -- p_cod_mod_padre
                        p_cod_modalidad,      -- p_cod_mad_padre
                        v_cod_tas_comision,   -- p_cod_tasa
                        v_val_comision,       -- p_val_tasa
                        v_comision,           -- p_monto
                        p_nro_secuencia,      -- p_nro_secuencia
                        p_error,              -- p_error
                        p_msj_error);         -- p_men_error
    END IF;

    -- se realiza el débito del IVA de la comisión
    IF v_iva > 0 AND p_error = '00' THEN
      lp_act_ope_debito(p_fecha,              -- p_fecha
                        p_hora,               -- p_hora
                        p_nro_cta_debito,     -- p_nro_cuenta
                        v_cod_tra_impuesto,   -- p_cod_transaccion
                        v_cod_tra_impuesto,   -- p_cod_tra_padre
                        'Iva s/Imp. '||p_con_comision, -- p_concepto
                        p_cod_oficina,        -- p_cod_ofi_origen
                        p_cod_modulo,         -- p_cod_mod_padre
                        p_cod_modalidad,      -- p_cod_mad_padre
                        v_cod_tas_impuesto,   -- p_cod_tasa
                        v_val_iva,            -- p_val_tasa
                        v_iva,                -- p_monto
                        p_nro_secuencia,      -- p_nro_secuencia
                        p_error,              -- p_error
                        p_msj_error);         -- p_men_error
    END IF;
  END lp_cob_comision;

BEGIN
  v_cod_tra_comision := fug_obt_parentes(p_cod_ente, p_cod_comision);

  -- cobro de comisión segun p_cod_comision
  if v_cod_tra_comision is not null then
    begin
      lp_cob_comision(v_cod_tra_comision,
                      p_des_comision,
                      p_can_credito,
                      p_nro_secuencia,
                      p_error,
                      p_msj_error);
    exception
      when others then
        p_error := '99';
        p_msj_error := substr(sqlerrm, 1, 1000);
    end;
  end if;

END;
/* Proceso invocado por el cierre mensual para el cobro de comisiones mensuales */
PROCEDURE PR_COB_COM_MENSUAL IS

v_nro_documento  ge_movimientos.nro_documento%type;
v_nro_secuencia  ge_movimientos.nro_secuencia%type;
v_cod_tra_padre  ge_movimientos.cod_tra_padre%type;
v_fec_actual     ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(4);
v_hora           ge_movimientos.hora%type := to_char(sysdate, 'hh24:mi:ss');
v_mes_actual     varchar(8)  := to_char(v_fec_actual, 'mm/yyyy');
v_msj_error      varchar2(1000);
v_error          varchar2(2) := '00';
v_exception      exception;

  -- Entes que tienen comisión mensual
  CURSOR c_entes IS
    SELECT ge.cod_ente, ge.cod_persona
      FROM ge_entes ge, ge_par_entes gep
     WHERE ge.tipo = 'PR'
       AND ge.cod_ente = gep.cod_ente
       AND gep.parametro = 'COD_TRA_COM_MENSUAL'
       AND gep.val_parametro IS NOT NULL;

  -- Cuentas débito para pago a proveedor
  CURSOR c_cuentas(p_cod_ente    IN ge_entes.cod_ente%type,
                   p_cod_moneda  IN ge_cuentas.cod_moneda%type,
                   p_cod_persona IN ge_clientes.cod_persona%type) IS
    SELECT gc.nro_cuenta, gc.cod_moneda, gc.cod_modulo, gc.cod_modalidad, gc.cod_oficina
      FROM ge_par_entes gp, ge_cuentas gc, ge_cta_clientes b
     WHERE trim(gp.val_parametro) = gc.nro_cuenta
       AND gp.parametro LIKE 'CTA_DEB_PPROV%'
       AND gp.cod_ente = p_cod_ente
       AND b.cod_persona = p_cod_persona
       AND gc.cod_modulo IN (3, 4)
       AND gc.cod_modalidad IN (31, 41, 334)
       AND gc.cod_moneda = p_cod_moneda
       AND gc.cod_moneda IN (pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_FUERTE)
       AND gc.nro_cuenta = b.nro_cuenta
       AND gc.estado NOT IN ('X','C','P')
       AND gp.val_parametro IS NOT NULL;

  -- Movimientos de la moneda del ente por mes
  CURSOR c_mov_ente(p_cod_ente IN ge_entes.cod_ente%type) IS
    SELECT gpp.cod_moneda, SUM(gpp.monto) acu_monto
      FROM ge_pag_proveedores gpp
     WHERE gpp.cod_ente = p_cod_ente
       AND to_char(gpp.fec_pago, 'mm/yyyy') = v_mes_actual
       AND gpp.estado = 'N'
  GROUP BY gpp.cod_moneda
    HAVING SUM(gpp.monto) > 0;

BEGIN
  begin
    -- Por cada ente que posea la transacción de comisión mensual
    for ent in c_entes loop
      -- Si tiene movimientos en el mes
      v_nro_secuencia := 0;
      v_cod_tra_padre := fug_obt_parentes(ent.cod_ente, 'COD_TRA_PAD_PPROV');
      pag_cta.pr_set_nro_documento3(ent.cod_ente);

      for mov_ente in c_mov_ente(ent.cod_ente) loop
        -- genero un número de documento para cobrar la comisión por movimiento de ente
        select s_nro_documento.nextval into v_nro_documento from dual;
        v_error := '00';

        -- Por moneda se intenta debitar la comisión
        for cta_ente in c_cuentas(ent.cod_ente, mov_ente.cod_moneda, ent.cod_persona)
        loop
          pag_prv.pr_cob_comision('COD_TRA_COM_MENSUAL',
                                  'Comisión Mensual Pago a Proveedores',
                                  ent.cod_ente,
                                  v_cod_tra_padre,
                                  cta_ente.nro_cuenta,
                                  cta_ente.cod_modulo,
                                  cta_ente.cod_modalidad,
                                  cta_ente.cod_moneda,
                                  mov_ente.acu_monto,
                                  cta_ente.cod_oficina,
                                  1,
                                  v_nro_documento,
                                  v_fec_actual,
                                  v_hora,
                                  v_nro_secuencia,
                                  v_error,
                                  v_msj_error,
                                  'S'); -- para que inserte en movimiento pendiente si puede
          if v_error = '00' then
            exit; -- se realizó el debito, continuamos
          else
            if v_error in ('99', '09') then
              -- hubo un error en el débito, salimos
              raise v_exception;
            end if;
          end if;
        end loop; -- c_cuentas
      end loop; -- c_mov_ente
      -- obtenemos el siguiente segundo para generar el movimiento
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
    end loop; -- c_entes
  exception
    when v_exception then
      raise_application_error(-20000, v_msj_error);
  end;
END;
-- OMM 26/04/2011 Procesar Pago a Proveedor ingresado desde la WEB.
PROCEDURE LP_REG_OPERACION(p_mensaje IN LONG, p_respuesta IN VARCHAR2) is
   PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
   v_respuesta ba_log_mensajeria.respuesta%type;
BEGIN
   v_respuesta := substr(p_respuesta, 1, 4000);
   insert into ba_log_mensajeria
      (mensaje, respuesta)
   values
      (p_mensaje, v_respuesta);
   commit;
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;
-- CR  17/09/2012 Ajustes para cobro de comisiones y opciones de pago
PROCEDURE PR_PRO_PAGO(p_ente in number default null,
                      p_nro_documento in number default null,
                      p_error out varchar2)  IS
v_cod_modulo         ge_movimientos.cod_modulo%type;
v_cod_modalidad      ge_movimientos.cod_modalidad%type;
v_estado             ge_cuentas.estado%type;
v_sal_disponible     ge_movimientos.monto%type;
v_procesa            VARCHAR2(1) := 'N';
---
v_cod_moneda         ba_monedas.cod_moneda%type;
v_fec_actual         ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(4);
v_nro_secuencia      ge_movimientos.nro_secuencia%type :=0;
v_hora               ge_movimientos.hora%type;
v_nro_documento      ge_movimientos.nro_documento%type;
--
v_mod_cta_credito    ge_movimientos.cod_modulo%type;
v_mad_cta_credito    ge_movimientos.cod_modalidad%type;
v_ofi_cta_credito    ge_movimientos.cod_oficina%type;
v_cod_oficina        ge_movimientos.cod_oficina%type;
--
v_cta_Debito         ge_cuentas.nro_cuenta%type;
v_acum_monto         ge_movimientos.monto%type := 0 ;
v_cod_tra_padre      ge_transacciones.cod_transaccion%type;
v_cod_tra_debito     ge_transacciones.cod_transaccion%type;
v_nom_ente           ge_entes.descripcion%type;
v_rub_debito         ge_parametros.parametro%type;
v_tip_comprobante    varchar2(5);
v_pag_fac_atrasada   varchar2(150);
v_ref_texto          varchar2(100);
v_est_modulo         ba_modulos.estado%type; -- OMM 13/12/2010
v_horario            varchar2(1)  := 'D'; -- Día normal -- OMM 13/12/2010
v_es_nocturno        varchar2(1)  := 'N'; -- No es nocturno
v_mensaje_error      VARCHAR2(1000);
v_con_credito        ge_movimientos.concepto%type; -- concepto movimiento crédito
v_con_debito         ge_movimientos.concepto%type; -- concepto movimiento débito
v_can_credito        number;
v_can_debito         number;
v_mod_reg_pago       varchar2(1) default 'N';
v_nro_lote           varchar2(20);


Cursor c_cabecera is
 Select * from bw_mov_pendientes b
 where to_date(substr(b.dato2,1,10),'DD/MM/YYYY') <= v_fec_actual -- OMM 21/11/2011 -- x si el pago se cargó el día anterior, igual debe procesar hoy
   and b.estado IN ('C', 'E')
   and b.cod_tip_mensaje = '075'
   and trim(b.dato) = nvl(p_ente, trim(b.dato))
   and b.nro_documento = nvl(p_nro_documento, b.nro_documento)
   and exists (Select 1 from ge_pag_proveedores gp
               where gp.cod_ente = trim(b.dato)
                 and gp.fec_pago = to_date(substr(b.dato2,1,10),'DD/MM/YYYY')
                 and gp.referencia = b.nro_documento
                 and gp.tip_carga = 'H'
                 and gp.estado in ('C', 'R'));

Cursor c_ordenes (p_nro_referencia number, p_cod_ente number) is
SELECT a.*,a.rowid from ge_pag_proveedores a
 where a.estado in('C','R')
   and trunc(a.fec_pago) <= v_fec_actual -- x si el pago se cargó el día anterior, igual debe procesar hoy
   and a.tip_carga = 'H' -- OMM Solo para Pagos Registrados por el HomeBanking
   and a.referencia = p_nro_referencia
   and a.cod_ente = p_cod_ente
   and a.for_pago != 'I'
   order by a.nro_cta_debito;

BEGIN
  v_hora      := to_char( sysdate, 'HH24:MI:SS' );
  --Para la registración anterior, misma hora
  v_nro_secuencia := 0;  --OMM 09/09/2016 DYDMR-4822. Se ajusta para generar correctamente el movimiento
  v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(4);
  If v_est_modulo = 2 then
    v_horario := 'D' ; -- N=Cerrado, D=Abierto
    v_es_nocturno := 'N';
  else
    v_horario := 'N' ; -- N=Cerrado, D=Abierto
    v_es_nocturno := 'S' ;
  end if;
  v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
  pag_cta.g_horario := v_horario;
    select nvl(max(a.nro_lote),0)
         into v_nro_lote
           from ge_pag_proveedores a
             where a.fec_pago= pag_cal.fu_obt_fec_actual(1)
               and a.cod_ente= p_ente;

--*
  For cab in c_cabecera loop
    p_error := '00' ;
    v_can_credito := 0;
    v_can_debito  := 0;
    v_acum_monto := 0;
    v_mensaje_error := null ;

    v_mod_reg_pago := fug_obt_parentes(cab.dato,'MOD_REG_PAG_PRV'); /* N=Normal, P=Por operación*/

    if v_mod_reg_pago is null then
      v_mod_reg_pago := 'N';
    end if;

    pag_prv.PR_OBT_DAT_PROVEEDOR (cab.dato, v_nom_ente, v_tip_comprobante, v_cod_tra_padre,
                   v_cta_Debito, v_pag_fac_atrasada, v_ref_texto, v_cod_tra_debito ,v_rub_debito);

    if cab.tip_pago = 'P' then -- Opción de pago Pago a proveedores
      v_con_credito := substr('Crédito por Pago a Proveedores: Empresa '||v_nom_ente, 1, 100);
      v_con_debito  := substr('Débito por Pago a Proveedores: Empresa '||v_nom_ente, 1, 100);
    else -- Opción de pago Crédito en Cuenta
      v_cod_tra_padre := fug_obt_parentes(cab.dato, 'COD_TRA_PAD_PRV_CREDITO');
      v_con_credito := substr('Crédito en Cuenta: Empresa '||v_nom_ente, 1, 100);
      v_con_debito  := substr('Débito por Transferencia: Empresa '||v_nom_ente, 1, 100);
    end if;

    BEGIN
      SELECT gc.cod_oficina, gc.cod_modulo, gc.cod_modalidad, gc.cod_moneda
        INTO v_cod_oficina, v_cod_modulo, v_cod_modalidad, v_cod_moneda
        FROM ge_cuentas gc
       WHERE nro_cuenta = cab.nro_cuenta;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        p_error := '01';
        v_mensaje_error := 'Cta. de Débito inexistente para el Ente '||cab.dato ;
      WHEN TOO_MANY_ROWS THEN
        p_error := '02';
        v_mensaje_error := 'Cta. de Débito '||cab.nro_cuenta||' duplicado en ge_cta_clientes o Maestro' ;
    END;
    if p_error = '00' then
      For reg in c_ordenes(cab.nro_documento, cab.dato) loop
        v_nro_documento:=null;
        --- busco los datos de la cta crédito, sólo si tuviera
        if reg.nro_cta_credito is not null then
          begin
            select cod_modulo, cod_modalidad, cod_oficina
              into v_mod_cta_credito, v_mad_cta_credito, v_ofi_cta_credito
              from ge_cuentas
             where nro_cuenta = reg.nro_cta_credito;
          exception
            when no_data_found then
              p_error := '03';
              v_mensaje_error := 'Cta. de crédito inexistente Nro '||reg.nro_cta_credito ;
            when others then
              p_error := '04';
              v_mensaje_error := 'Eror Critico con Cta. de crédito. '||sqlerrm ;
            end;
        end if;

        -- OMM 09/09/2016 DYDMR-4822. Se ajusta para generar correctamente el movimiento
        if v_nro_secuencia > 990 then
              v_nro_secuencia := -999;
        elsif v_nro_secuencia < 0 and v_nro_secuencia > -10 then
              v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
              v_nro_secuencia := 0 ;
        end if;

        --Se guarda Hora y Nro.Documento Acorde a Tipo de Registración
        if v_mod_reg_pago ='N' then
          v_nro_documento:=cab.nro_documento;
        else
          --Por Operación
          v_hora      := to_char( sysdate, 'HH24:MI:SS' );
          v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
           --- inserto Nro.Doc.Diferente
           SELECT s_nro_documento.nextval
              INTO v_nro_documento
               FROM dual;
           v_nro_secuencia := 0 ;  -- OMM feb/2017 DYDMR-6125
        end if;

        --CRÉDITO EN CUENTA
        if reg.for_pago = 'C' and p_error = '00' then
          /* acreditar la cuenta de crédito */
          pag_cta.pr_act_operacion(reg.nro_cta_credito,
                                   v_hora,            --HORA
                                   'C',
                                   reg.cod_moneda,    --Moneda de la Operación
                                   reg.monto,
                                   v_cod_tra_padre,   --COD_TRA_PADRE
                                   602,               -- COD_TRA_HIJO
                                   v_nro_documento,   --cab.nro_documento, --:PROV.NRO_RECIBO,
                                   NULL,              --COTIZACION
                                   v_cod_oficina,     --cod_ofi_origen
                                   v_cod_modulo,      --cod_mod_padre
                                   v_cod_modalidad,   --cod_mad_padre
                                   null,              --cod_tasa
                                   null,              --val_tasa
                                   v_con_credito,     --descripción
                                   'S',               --emi_aviso
                                   v_nro_secuencia,
                                   v_fec_actual);

          if pag_cta.fu_obt_cod_error() <> 0 then
            p_error := '05';
            v_mensaje_error := 'Error con Cta Cred '|| reg.nro_cta_credito || '-'||pag_cta.fu_obt_msj_error;
          else
            v_acum_monto := nvl(v_Acum_monto,0) + reg.monto;
            v_can_credito := v_can_credito + 1;
            --actualizar movimientos con el nro_orden
            if v_horario = 'D' then
              update ge_movimientos
                 set nro_documento2 = reg.nro_orden,
                     nro_documento3 = reg.cod_ente
               where fecha = v_fec_actual
                 and cod_usuario = user
                 and hora = v_hora
                 and reversado ='N'
                 and nro_secuencia = v_nro_secuencia
                 and cod_tra_padre = v_cod_tra_padre;
            else
              update ge_movimientos_noc
                 set nro_documento2 = reg.nro_orden,
                     nro_documento3 = reg.cod_ente
               where fecha = v_fec_actual
                 and cod_usuario = user
                 and hora = v_hora
                 and reversado ='N'
                 and nro_secuencia = v_nro_secuencia
                 and cod_tra_padre = v_cod_tra_padre;
            end if;
          end if;
        End if;
        ---Si no hubo errores actualiza tablas
        If p_error = '00' then
          UPDATE ge_pag_proveedores
             SET nro_recibo      = null,
                 estado          = 'N',
                 fec_pago        = v_fec_actual,
                 hora            = v_hora,
                 nro_documento   = v_nro_documento,
                 nro_pago        = to_char(pag_cal.fu_obt_fec_actual(1),'yymmdd')||replace(v_hora,':','')||v_nro_secuencia,
                 nro_lote        = to_number(v_nro_lote)+1
           WHERE rowid= reg.rowid;
              /*cod_ente        = reg.cod_ente
             AND trunc(fec_pago) <= v_fec_actual -- x si el pago se cargó el día anterior, igual debe procesar hoy
             AND nro_orden       = reg.nro_orden
             AND nvl(nro_factura,'0') = nvl(reg.nro_factura,'0') --CC-Mejoras en Pago a Proveedores/PCCMEJPP-93
             AND usu_insercion   = reg.usu_insercion
             AND estado in ('C','R');*/

          IF SQL%NOTFOUND THEN
            p_error := '06';
            v_mensaje_error := 'Error al actualizar GE_PAG_PROVEEDORES. Ente-Orden: '||reg.cod_ente||'-'||reg.nro_orden;
          END IF;
        End if;
        --------------------------------------------------------------------
        if v_mod_reg_pago = 'P' then -- Modalidad de Pago D/C por Operación.
          if v_cod_modalidad in (31,41,334) and p_error = '00' then
            pag_cta.pr_ver_operacion(cab.nro_cuenta,
                                     v_cod_tra_padre,
                                     v_cod_modulo,
                                     v_cod_modalidad,
                                     'D',
                                     v_cod_moneda,
                                     reg.monto,
                                     v_cod_oficina,
                                     v_cod_modulo,
                                     v_cod_modalidad,
                                     v_estado,
                                     v_sal_disponible,
                                     v_procesa,
                                     503);
            if v_procesa = 'N' then
              p_error := '07';
              v_mensaje_error := 'Error con Cta Debito '||cab.nro_cuenta||'-'||pag_cta.fu_obt_msj_error;
            else
              v_can_debito := v_can_debito + 1;

              if p_error = '00' then
                /* establecemos el código del ente en nro_documento3 para sumarizar
                   los límites de operación por ente en pago a proveedores */
                pag_cta.pr_set_nro_documento3(cab.dato);

                /* debitar a la cuenta de débito */
                pag_cta.pr_act_operacion(cab.nro_cuenta,
                                         v_hora,--HORA
                                         'D',
                                         v_cod_moneda,
                                         reg.monto,
                                         v_cod_tra_padre,--COD_TRA_PADRE
                                         nvl(v_cod_tra_debito,503),    -- COD_TRA_HIJO
                                         v_nro_documento,  --cab.nro_documento, --:PROV.NRO_RECIBO,
                                         null,                     --COTIZACION
                                         v_cod_oficina,    --cod_ofi_origen
                                         v_cod_modulo,    --cod_mod_padre
                                         v_cod_modalidad, --cod_mad_padre
                                         null, --cod_tasa
                                         null, --val_tasa
                                         v_con_debito,
                                         'S', --emi_aviso
                                         v_nro_secuencia,
                                         v_fec_actual);

                if pag_cta.fu_obt_cod_error() <> 0 then
                  p_error := '09';
                  v_mensaje_error := 'Error al Tratar de Procesar Debito. '||pag_cta.fu_obt_msj_error;
                end if;
              end if;

              v_acum_monto := 0 ;
            End if;
          End if ; -- end if v_cod_modalidad in (31,41) débito
        end if;
      End Loop; -- For reg in c_ordenes
   IF v_mod_reg_pago != 'P' THEN -- Modalidad de Pago D/C por Operación.
      if v_cod_modalidad in (31,41,334) and p_error = '00' then
        pag_cta.pr_ver_operacion(cab.nro_cuenta,
                                 v_cod_tra_padre,
                                 v_cod_modulo,
                                 v_cod_modalidad,
                                 'D',
                                 v_cod_moneda,
                                 v_acum_monto, --cab.monto,  -- DYDMR-3116 -- CN: 03/2016 -- Debe verificar solo el monto pendiente no el total del lote.
                                 v_cod_oficina,
                                 v_cod_modulo,
                                 v_cod_modalidad,
                                 v_estado,
                                 v_sal_disponible,
                                 v_procesa,
                                 503);
        if v_procesa = 'N' then
          p_error := '10';
          v_mensaje_error := 'Error con Cta Debito '||cab.nro_cuenta||'-'||pag_cta.fu_obt_msj_error;
        else
          -- Verifico si el detallado es igual al total para debitar
         /* if v_acum_monto <> cab.monto then
            p_error := '11';
            v_mensaje_error := 'Monto Detalle no coincide con Total. Ente: '||cab.dato ;
          end if ;*/

          if p_error = '00' and v_acum_monto > 0 then
            /* establecemos el código del ente en nro_documento3 para sumarizar
               los límites de operación por ente en pago a proveedores */
            pag_cta.pr_set_nro_documento3(cab.dato);

            /* debitar a la cuenta de débito */
            pag_cta.pr_act_operacion(cab.nro_cuenta,
                                     v_hora,--HORA
                                     'D',
                                     v_cod_moneda,
                                     v_acum_monto,
                                     v_cod_tra_padre,--COD_TRA_PADRE
                                     nvl(v_cod_tra_debito,503),    -- COD_TRA_HIJO
                                     cab.nro_documento, --:PROV.NRO_RECIBO,
                                     null,                     --COTIZACION
                                     v_cod_oficina,    --cod_ofi_origen
                                     v_cod_modulo,    --cod_mod_padre
                                     v_cod_modalidad, --cod_mad_padre
                                     null, --cod_tasa
                                     null, --val_tasa
                                     v_con_debito,
                                     'S', --emi_aviso
                                     v_nro_secuencia,
                                     v_fec_actual);

            if pag_cta.fu_obt_cod_error() <> 0 then
              p_error := '12';
              v_mensaje_error := 'Error al Tratar de Procesar Debito. '||pag_cta.fu_obt_msj_error;
            end if;
          end if;
          -- se cobran las comisiones correspondientes
          if p_error = '00' and v_acum_monto > 0 then
            pr_cob_comision('COD_TRA_COM_INDIVIDUAL',
                            'Comisión por Crédito Individual de Pago a Proveedores',
                            cab.dato,
                            v_cod_tra_padre,
                            cab.nro_cuenta,
                            v_cod_modulo,
                            v_cod_modalidad,
                            v_cod_moneda,
                            v_acum_monto,
                            v_cod_oficina,
                            v_can_credito,
                            cab.nro_documento,
                            v_fec_actual,
                            v_hora,
                            v_nro_secuencia,
                            p_error,
                            v_mensaje_error);
          end if;

          if p_error = '00' and v_acum_monto > 0 then
            pr_cob_comision('COD_TRA_COM_SERVICIO',
                            'Comisión por Servicio de Pago a Proveedores',
                            cab.dato,
                            v_cod_tra_padre,
                            cab.nro_cuenta,
                            v_cod_modulo,
                            v_cod_modalidad,
                            v_cod_moneda,
                            v_acum_monto,
                            v_cod_oficina,
                            1,
                            cab.nro_documento,
                            v_fec_actual,
                            v_hora,
                            v_nro_secuencia,
                            p_error,
                            v_mensaje_error);
          end if;

        End if;
      End if ; -- end if v_cod_modalidad in (31,41)
    ELSE
              -- se cobran las comisiones Por la Modalidad D/C Por Operación.
              if p_error = '00' and v_acum_monto > 0 then
                pr_cob_comision('COD_TRA_COM_INDIVIDUAL',
                                'Comisión por Crédito Individual de Pago a Proveedores',
                                cab.dato,
                                v_cod_tra_padre,
                                cab.nro_cuenta,
                                v_cod_modulo,
                                v_cod_modalidad,
                                v_cod_moneda,
                                v_acum_monto,
                                v_cod_oficina,
                                v_can_credito,
                                cab.nro_documento,
                                v_fec_actual,
                                v_hora,
                                v_nro_secuencia,
                                p_error,
                                v_mensaje_error);
              end if;

              if p_error = '00' and v_acum_monto > 0 then
                pr_cob_comision('COD_TRA_COM_SERVICIO',
                                'Comisión por Servicio de Pago a Proveedores',
                                cab.dato,
                                v_cod_tra_padre,
                                cab.nro_cuenta,
                                v_cod_modulo,
                                v_cod_modalidad,
                                v_cod_moneda,
                                v_acum_monto,
                                v_cod_oficina,
                                v_can_debito,
                                cab.nro_documento,
                                v_fec_actual,
                                v_hora,
                                v_nro_secuencia,
                                p_error,
                                v_mensaje_error);
              end if;
              v_acum_monto := 0 ;
    END IF;
    end if ; -- end if (p_error = '00')
    -- Veifica si terminó bien hace commit, sino hace rollback
    if p_error <> '00' then
      /*commit ;
    else*/
      it_mail.mail( fug_obt_dir_correo,
                    fug_obt_pardinamico('SUE_DIR_CORREO'),
                    'Error al Tratar de Procesar Pago a Proveedores',
                    'ERROR EN PROCESO DE CRÉDITO Y DÉBITO PARA PAGO A PROVEEDORES'|| chr(10) ||chr(10) ||
                    'Codigo  : ' || cab.dato|| chr(10) ||
                    'Empresa : ' || v_nom_ente|| chr(10) ||
                    'Codigo de Error: ' || p_error || chr(10) ||
                    'Error Registrado: ' || v_mensaje_error || chr(10) ||chr(10) ||
                    'Atentamente. '
                    );
      --rollback;
    end if ;
    -- limpiamos la variable global
    pag_cta.pr_set_nro_documento3(NULL);
  End Loop;

EXCEPTION
  when others then
    p_error := '99';
    -- limpiamos la variable global
    pag_cta.pr_set_nro_documento3(NULL);
    lp_reg_operacion('pag_prv.pr_pro_pago- ente:'||p_ente||', nro_doc:'||p_nro_documento, SQLERRM);
END PR_PRO_PAGO;
--NVB-2232
/* Proceso de pago a proveedores a través de SNP */
PROCEDURE PR_PRO_PAG_SNP (p_cod_ente in ge_entes.cod_ente%type,
                          p_usuario  in ba_usuarios.cod_usuario%type,
                          p_error    out varchar2,
                          p_fec_pago date default null,
                          p_nro_archivo ge_pag_proveedores.nro_archivo%type default null) IS

  rg_ge_snp_trans       pas_snp.rg_msj;
  v_cod_tip_ope_av      ge_snp_transferencias.cod_tip_operacion%type;
  v_cod_sub_tip_ope_av  ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_cod_tip_ope_bv      ge_snp_transferencias.cod_tip_operacion%type;
  v_cod_sub_tip_ope_bv  ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_cod_sub_tip_ope_bcp ge_snp_transferencias.cod_sub_tip_operacion%type := nvl(fug_obt_pardinamico('SNP_SUB_TIP_OPE_TRA_BCP'),'005');  -- DDSI-62
  v_cod_mon_cta_debito  ge_cuentas.cod_moneda%type;
  v_cant                number;
  v_nro_con_cambio      number(18);
  v_can_con_cambio      number(9);
  v_est_periodo         varchar2(1);
  v_nro_lote            varchar2(20);
  v_concepto            varchar2(1000);
  v_lon_nro_referencia  number(10);
  v_lon_concepto        number(10);
  v_lon_nro_factura     number(10);
  v_lon_cadena          number(10);
  v_disponible          number(10);
  v_cli_pue_enviar      varchar2(1);
  v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_spi_hab_pp          VARCHAR2(1) := fug_obt_pardinamico('SPI_HAB_PP');
  v_cod_swift           gv_snp_participantes.cod_swift%type;


  cursor c_pagos is
    select a.*,a.rowid
      from ge_pag_proveedores a
     where a.cod_ente = p_cod_ente
       and a.estado in('C','R')
       and a.usu_insercion = p_usuario
       and a.for_pago = 'I'
       and (p_fec_pago is null or trunc(a.fec_pago) = trunc(p_fec_pago))
       and (p_nro_archivo is null or a.nro_archivo = p_nro_archivo)
     order by a.nro_cta_debito;
       --for update of estado, nro_referencia;

  cursor c_deb is
    select b.* --a.nro_referencia, b.cod_msj_swift, b.cod_tip_operacion, b.cod_sub_tip_operacion
      from ge_pag_proveedores a, ge_snp_transferencias b
     where a.nro_referencia = b.nro_referencia
       and a.cod_ente = p_cod_ente
       and a.estado = 'N'
       and a.usu_insercion = p_usuario
       and a.for_pago = 'I'
       and (p_fec_pago is null or trunc(a.fec_pago) = trunc(p_fec_pago))
       and (p_nro_archivo is null or a.nro_archivo = p_nro_archivo)
       and b.situacion = 'P'
       and b.estado = 'A'
     order by a.nro_cta_debito;
BEGIN

   if fug_obt_parentes(p_cod_ente, 'SNP_HAB_PROVEEDORES') != 'S' then
      p_error := '75-ENTIDAD NO HABILITADA PARA PAGOS INTERBANCARIA';
      return;
   end if;

   /*Datos en común*/
   BEGIN
   --hallo tipo y subtipo de op. para el ente
   v_cod_tip_ope_av     := fug_obt_val_delimitador(fug_obt_parentes(p_cod_ente, 'SNP_TIP_AV_PROVEEDORES'), ',', 1);
   v_cod_sub_tip_ope_av := fug_obt_val_delimitador(fug_obt_parentes(p_cod_ente, 'SNP_TIP_AV_PROVEEDORES'), ',', 2);
   v_cod_tip_ope_bv     := fug_obt_val_delimitador(fug_obt_parentes(p_cod_ente, 'SNP_TIP_BV_PROVEEDORES'), ',', 1);
   v_cod_sub_tip_ope_bv := fug_obt_val_delimitador(fug_obt_parentes(p_cod_ente, 'SNP_TIP_BV_PROVEEDORES'), ',', 2);
   rg_ge_snp_trans.tip_cargo         := fug_obt_parentes(p_cod_ente, 'SNP_TIP_CAR_PROVEEDORES');
   EXCEPTION
     WHEN OTHERS THEN
       p_error := 'ERROR AL OBTENER PARAMETROS DE ENTE: '||sqlerrm;
       return;
   END;

   rg_ge_snp_trans.cod_modulo        := pas_snp.fu_obt_cod_mod_padre;
   rg_ge_snp_trans.cod_modalidad     := pas_snp.fu_obt_cod_mad_padre;
   rg_ge_snp_trans.tip_mensaje       := 'CRED';
   rg_ge_snp_trans.origen            := 'I';
   rg_ge_snp_trans.plataforma        := 'X';
   rg_ge_snp_trans.indemnizado       := 'N';

   -- Hallo Datos del Ente solicitante
   begin
       select a.cod_persona,
              a.descripcion,
              b.cod_tip_documento,
              b.nro_documento
         into rg_ge_snp_trans.cod_per_solicitante,
              rg_ge_snp_trans.nom_solicitante,
              rg_ge_snp_trans.cod_tip_doc_solicitante,
              rg_ge_snp_trans.nro_doc_solicitante
         from ge_entes a,
              ba_personas b
        where cod_ente = p_cod_ente
          and a.cod_persona = b.cod_persona;
   exception
      when others then
         p_error := 'ERROR AL HALLAR DATOS DEL ENTE SOLICITANTE: '||sqlerrm;
         return;
   end;

   rg_ge_snp_trans.cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
    select nvl(max(a.nro_lote),0)
         into v_nro_lote
           from ge_pag_proveedores a
             where a.fec_pago= pag_cal.fu_obt_fec_actual(1)
               and a.cod_ente=p_cod_ente;
   for reg in c_pagos loop
      --Se limpian variables para volver a cargar
      rg_ge_snp_trans.nro_referencia := null;
      rg_ge_snp_trans.fecha := null;
      rg_ge_snp_trans.fec_valor := null;
      rg_ge_snp_trans.hora  := null;
      rg_ge_snp_trans.situacion := null;
      rg_ge_snp_trans.estado := null;
      rg_ge_snp_trans.nro_cta_solicitante:=null;
      v_cod_mon_cta_debito:=null;
      rg_ge_snp_trans.cod_oficina:=null;
      p_error := null;
      rg_ge_snp_trans.ind_valor :=null;
      rg_ge_snp_trans.cod_msj_swift := null;
      rg_ge_snp_trans.cod_tip_operacion := null;
      rg_ge_snp_trans.cod_sub_tip_operacion := null;
      rg_ge_snp_trans.fec_ingreso := null;
      rg_ge_snp_trans.cod_moneda := null;
      rg_ge_snp_trans.monto := null;
      rg_ge_snp_trans.nro_cta_pte_solicitante :=null;
      rg_ge_snp_trans.cod_tip_doc_beneficiario := null;
      rg_ge_snp_trans.nro_doc_beneficiario :=null;
      rg_ge_snp_trans.cod_per_beneficiario := null;
      rg_ge_snp_trans.nom_beneficiario := null;
      rg_ge_snp_trans.dir_beneficiario := null;
      rg_ge_snp_trans.nro_cta_beneficiario := null;
      rg_ge_snp_trans.cod_swi_pte_beneficiario:=null;
      rg_ge_snp_trans.nro_cta_pte_beneficiario:=null;
      rg_ge_snp_trans.concepto:=null;
      rg_ge_snp_trans.prioridad:=null;
      rg_ge_snp_trans.msj_swift :=null;
      rg_ge_snp_trans.ben_dir_correo := null;
      rg_ge_snp_trans.cod_tra_padre := null;
      pas_snp.g_msj_error:=null;
      --
      rg_ge_snp_trans.nro_referencia := pas_snp.fu_obt_sig_nro_referencia;
      rg_ge_snp_trans.cod_usuario := null;
      rg_ge_snp_trans.situacion := 'P';
      rg_ge_snp_trans.estado := 'A';

      --Obtengo datos de la cta de débito una sola vez
      if nvl(rg_ge_snp_trans.nro_cta_solicitante, 'X') != reg.nro_cta_debito then
         rg_ge_snp_trans.nro_cta_solicitante := reg.nro_cta_debito;
         pag_cta.pr_obt_cuenta(rg_ge_snp_trans.nro_cta_solicitante);
         v_cod_mon_cta_debito := pag_cta.g_ctas.cod_moneda;
         rg_ge_snp_trans.cod_oficina := pag_cta.g_ctas.cod_oficina;
         if pag_cta.fu_obt_cod_error <> 0 then
           p_error := pag_cta.fu_obt_msj_error;
           --exit;
           return;
         end if;
      end if;
      rg_ge_snp_trans.ind_valor := reg.ind_valor;
      v_cli_pue_enviar := fug_pue_env_tra_fue_hora('103','001','002',302,reg.monto, reg.cod_moneda, reg.fec_pago, reg.nro_cta_debito);


       --Hallo el swift de la entidad de destino
      begin
        select b.cod_swift
          into v_cod_swift
          from gv_snp_participantes b
         where (reg.ent_bca_beneficiario = b.cod_banco or reg.ent_bca_beneficiario = b.cod_ente)
           and b.cod_persona != fug_obt_per_entidad;
      exception
          when others then
             p_error := 'ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.ent_bca_beneficiario||': '||sqlerrm;
             return;
      end;

      if  fug_val_mx_spi( v_cod_swift,
                          reg.nro_doc_beneficiario,
                          reg.nro_cta_beneficiario,
                          reg.cod_moneda,
                          reg.monto,'E')='S' and v_spi_hab_pp='S' then

                     rg_ge_snp_trans.ind_valor := 'N';
                     rg_ge_snp_trans.cod_msj_swift := 102;
                     rg_ge_snp_trans.cod_tip_operacion := v_cod_tip_ope_bv;
                     rg_ge_snp_trans.cod_sub_tip_operacion := v_cod_sub_tip_ope_bv;
      else
                 if reg.ind_valor = 'A'
                 and paw_bas.fu_obt_tip_TransfInterbancaria('103','001','002',302,reg.monto, reg.cod_moneda, reg.fec_pago, fug_obt_cli_principal(rg_ge_snp_trans.nro_cta_solicitante)) ='103' then
                     rg_ge_snp_trans.ind_valor := 'S';
                     rg_ge_snp_trans.cod_msj_swift := 103;
                     rg_ge_snp_trans.cod_tip_operacion := v_cod_tip_ope_av;
                     rg_ge_snp_trans.cod_sub_tip_operacion := v_cod_sub_tip_ope_av;
                     if ((fug_den_per_act_snp('103','001','002',302,3) = 'S') and
                         (reg.cod_moneda = v_cod_mon_local) and
                         (fug_obt_mon_cta(reg.nro_cta_debito) <> v_cod_mon_local) and
                         (v_cli_pue_enviar = 'S'))
                          then
                          rg_ge_snp_trans.ind_valor := 'N';
                          rg_ge_snp_trans.cod_msj_swift := 102;
                          rg_ge_snp_trans.cod_tip_operacion := v_cod_tip_ope_bv;
                          rg_ge_snp_trans.cod_sub_tip_operacion := v_cod_sub_tip_ope_bv;
                     end if;
                  else
                     rg_ge_snp_trans.ind_valor := 'N';
                     rg_ge_snp_trans.cod_msj_swift := 102;
                     rg_ge_snp_trans.cod_tip_operacion := v_cod_tip_ope_bv;
                     rg_ge_snp_trans.cod_sub_tip_operacion := v_cod_sub_tip_ope_bv;
                  end if;
     end if;

      --
      rg_ge_snp_trans.fec_ingreso := pag_cal.FU_OBT_FEC_ACTUAL(1);
      rg_ge_snp_trans.fec_valor := reg.fec_pago;
      rg_ge_snp_trans.cod_moneda := reg.cod_moneda;
      rg_ge_snp_trans.monto := reg.monto;
      rg_ge_snp_trans.nro_cta_pte_solicitante := pas_snp.fu_obt_cta_ban_participante(rg_ge_snp_trans.cod_swi_pte_solicitante,
                                                                                     rg_ge_snp_trans.cod_moneda);
      /*--------------
      --BENEFICIARIO--
      ----------------*/
      rg_ge_snp_trans.cod_tip_doc_beneficiario := reg.cod_tip_doc_beneficiario;
      rg_ge_snp_trans.nro_doc_beneficiario := reg.nro_doc_beneficiario;
      rg_ge_snp_trans.cod_per_beneficiario := fue_obt_cod_persona(reg.nro_doc_beneficiario);
      rg_ge_snp_trans.nom_beneficiario := reg.beneficiario;
      rg_ge_snp_trans.dir_beneficiario := reg.dir_beneficiario;
      rg_ge_snp_trans.nro_cta_beneficiario := reg.nro_cta_beneficiario;
      rg_ge_snp_trans.ben_dir_correo := substr(reg.ben_dir_correo, 1, 80);
      --
      if rg_ge_snp_trans.cod_tip_doc_beneficiario is null then
        p_error := 'ERROR. CODIGO DE TIPO DE DOCUMENTO BENEFICIARIO NO PUEDE SER NULO';
        return;
      end if;
      --
      if rg_ge_snp_trans.nro_doc_beneficiario is null then
        p_error := 'ERROR. NUMERO DE DOCUMENTO BENEFICIARIO NO PUEDE SER NULO';
        return;
      end if;
      --
      if rg_ge_snp_trans.nom_beneficiario is null then
        p_error := 'ERROR. NOMBRE BENEFICIARIO NO PUEDE SER NULO';
        return;
      end if;
      --
      if rg_ge_snp_trans.nro_cta_beneficiario is null then
        p_error := 'ERROR. NUMERO DE CUENTA BENEFICIARIO NO PUEDE SER NULO';
        return;
      end if;

     --Si es 102 y la moneda destino es en USD
     if rg_ge_snp_trans.cod_msj_swift= 102
         and rg_ge_snp_trans.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL then
         p_error := 'ERROR. para MT 102 - Debe ser moneda local';
         return;
     end if;
      --Hallo el swift de la entidad de destino
      begin
        select b.cod_swift
          into rg_ge_snp_trans.cod_swi_pte_beneficiario
          from /*ge_bancos a,
               */gv_snp_participantes b
         where /*lpad(a.cod_bco_central,4,'1000') = lpad(reg.ent_bca_beneficiario,4,'1000')
           and a.cod_banco = b.cod_banco*/
           (reg.ent_bca_beneficiario = b.cod_banco or reg.ent_bca_beneficiario = b.cod_ente)
           and b.cod_persona != fug_obt_per_entidad;
      exception
          when others then
             p_error := 'ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.ent_bca_beneficiario||': '||sqlerrm;
             return;
      end;

      --  Si es BCP hay que cambiar el sub tipo de operación a 005
      IF rg_ge_snp_trans.cod_swi_pte_beneficiario = nvl(fug_obt_pardinamico('SNP_BIC_BCP'),'X') THEN
         rg_ge_snp_trans.cod_sub_tip_operacion := v_cod_sub_tip_ope_bcp; -- DDSI-62
         -- No se pueden hacer transferencias por lotes al BCP
         IF rg_ge_snp_trans.cod_tip_operacion = '011' THEN
            p_error := 'La prioridad de envío no está permitida para transferencias al BCP.';
            return;
         END IF;
      END IF;
      rg_ge_snp_trans.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(rg_ge_snp_trans.cod_swi_pte_beneficiario,
                                                                                     rg_ge_snp_trans.cod_moneda);

      if rg_ge_snp_trans.nro_cta_pte_beneficiario is null then
        p_error := 'ERROR. Cta. Pte. Beneficiario nulo para código swift: '
        ||rg_ge_snp_trans.cod_swi_pte_beneficiario||' Moneda: '||rg_ge_snp_trans.cod_moneda;
        return;
      end if;
      --19/02/2016 Se ajusta el concepto
      --rg_ge_snp_trans.concepto := reg.concepto;

      /* --wa:04_07_2016 se cambia la lógica, parrafo inferior
      v_concepto:= null;
      v_concepto:= 'Factura/s:';
      if reg.nro_factura is null or reg.nro_factura='0' then
         --No se cargo la factura, tomamos de ref_facturas (54 posiciones)
         v_concepto:=  v_concepto||trim(substr(trim(reg.ref_facturas),1,54));
      else
         --Si tiene cargado datos este campo (se toma 15 posiciones del campo)
         v_concepto:=  v_concepto||trim(substr(trim(reg.nro_factura),1,15));
      end if;
       -- Le agregamos concepto
      if reg.concepto is not null then
        v_concepto:=  v_concepto||' '||substr(reg.concepto,1,35);
      end if;

      rg_ge_snp_trans.concepto := substr(trim(v_concepto),1,95);
      */
      --*************wa:04_07_2016 se cambia la lógica de concepto******
      --Se toman: 100 posiciones de REF_FACTURAS(Si es nulo o no completa 100)
      --Se toman: Tomamos Concepto y Finalmente NRO_FACTURA hasta completar 100.
      v_concepto:= null;
      v_lon_nro_referencia:=0;
      v_lon_nro_factura:=0;
      v_lon_concepto:=0;
      v_lon_cadena:=0;
      --Hallamos las longitudes.
      v_lon_nro_referencia:= length(reg.ref_facturas);
      v_lon_nro_factura:= length(reg.nro_factura);
      v_lon_concepto:= length(reg.concepto);
      --***Verificamos Ref_facturas***
      if nvl(v_lon_nro_referencia,0) > 0 and nvl(v_lon_nro_referencia,0)<= 100 then
         --Si no es nulo y es menor o igual a 100 tomamos todas las posiciones
         v_concepto:= trim(substr(reg.ref_facturas,1,v_lon_nro_referencia));
         v_lon_cadena:= length(v_concepto);
      elsif nvl(v_lon_nro_referencia,0) > 0 and nvl(v_lon_nro_referencia,0) > 100 then
         --Sino es nulo y tiene mas de 100 caracteres, cortamos en 100
         v_concepto:= trim(substr(reg.ref_facturas,1,100));
         v_lon_cadena:= length(v_concepto);
      end if;
      --***Verificamos Concepto***
      if nvl(v_lon_cadena,0) < 100 then
        v_disponible:= 100 - nvl(v_lon_cadena,0);
        if nvl(v_lon_concepto,0) > 0 then
           --Si no esta nulo el campo concepto.
          v_concepto:= trim(v_concepto||' '|| substr(reg.concepto,1,v_disponible -1));
          v_lon_cadena:= length(v_concepto);
        end if;

      end if;
      --Verificamos NRO_FACTURA
      if nvl(v_lon_cadena,0) < 100 then
          v_disponible:=0;
          -- 100 + 1 Espacio por concepto
          v_disponible:= 101 - nvl(v_lon_cadena,0);
          if nvl(v_lon_nro_factura,0) > 0 then
            if v_disponible >= v_lon_nro_factura then -- DYDMR-4554 -- 07/2016 -- Solo si la longitud disponible es mayor o igual al numero de factura
             v_concepto:= trim(v_concepto||' '|| substr(reg.nro_factura,1,v_disponible -1));
            end if;
          end if;
      end if;
      --Finalmente cortamos a 100 ya que es el máximo. (Le quitamos espacio sino se utliza, dos espacios tiene)
      rg_ge_snp_trans.concepto := trim(substr(trim(v_concepto),1,100));
      --******************************************************************
      rg_ge_snp_trans.cod_tra_padre := 302; -- transaccion proveedores

      begin
        select m.prioridad
          into rg_ge_snp_trans.prioridad
          from ge_snp_par_mensajes m
         where m.cod_msj_swift = rg_ge_snp_trans.cod_msj_swift
           and m.cod_tip_operacion = rg_ge_snp_trans.cod_tip_operacion
           and m.cod_sub_tip_operacion = rg_ge_snp_trans.cod_sub_tip_operacion
           and m.cod_tra_padre = 302 ; -- Transacción Padre de Pago a Proveedores
      exception
          when others then
             p_error := 'ERROR AL HALLAR PRIORIDAD: '||sqlerrm;
             return;
      end;

      begin

         pas_snp.pr_ins_transferencias(rg_ge_snp_trans);
--
         if pas_snp.fu_obt_cod_error <> 0 then
           p_error := pas_snp.fu_obt_msj_error;
           return;
         end if;
--
      exception
        when others then
           p_error := 'ERROR AL INSERTAR TRANSFERENCIA: '||sqlerrm;
           --exit;
           return;
      end;
      --Si es alto valor recupero
      if rg_ge_snp_trans.cod_msj_swift = 103 then
         begin
            rg_ge_snp_trans.msj_swift := pas_snp.fu_obt_msj_mt103(rg_ge_snp_trans.nro_referencia);
           if pas_snp.fu_obt_cod_error <> 0 then
             p_error := 'OBTENER MENSAJERÍA: '||pas_snp.fu_obt_msj_error;
             return;
           end if;
         exception
            when others then
               p_error := 'OBTENER MENSAJERÍA: '||sqlerrm;
               return;
         end;

         update ge_snp_transferencias
            set msj_swift = rg_ge_snp_trans.msj_swift
          where nro_referencia = rg_ge_snp_trans.nro_referencia;
      end if;

      if p_error is null then
        begin
         --
           update ge_pag_proveedores
              set nro_referencia = rg_ge_snp_trans.nro_referencia,
                  nro_documento= rg_ge_snp_trans.nro_referencia,
                  estado = 'N',
                  nro_pago        = to_char(pag_cal.fu_obt_fec_actual(1),'yymmdd')||replace(to_char(sysdate,'hh24:mi:ss'),':','')||'1',
                  nro_lote        = to_number(v_nro_lote)+1
            where/* NRO_ORDEN= REG.NRO_ORDEN
               and usu_insercion = p_usuario
               and for_pago = 'I'
               and (p_fec_pago is null or fec_pago = p_fec_pago)
               and (p_nro_archivo is null or nro_archivo = p_nro_archivo)*/
               rowid= reg.rowid;
            --current of c_pagos;
        exception
          when others then
             p_error := 'ERROR AL ACTUALIZAR PAGO: '||sqlerrm;
             --exit;
             return;
        end;

        if reg.nro_con_cambio is not null then
           begin
              v_can_con_cambio:=0;

              select count(a.nro_operacion)
                into v_can_con_cambio
                from lc_ope_pendientes a
               where a.nro_operacion=reg.nro_con_cambio
                 and a.liquidado='S'
                 and rownum=1
                 and trunc(a.fec_insercion) = trunc(sysdate);

         /*     select count(*), b.nro_con_cambio
                into v_can_con_cambio,v_nro_con_cambio
                from ge_pag_proveedores b
               where b.cod_ente = p_cod_ente
                 and b.fec_pago = pag_cal.fu_obt_fec_actual(1)
                 and b.nro_referencia = rg_ge_snp_trans.nro_referencia
                 and exists  (select a.nro_operacion
                                from lc_ope_pendientes a
                               where a.nro_operacion=b.nro_con_cambio
                                 and a.liquidado='S'
                                 and rownum=1
                                 and trunc(a.fec_insercion) = trunc(sysdate)
                              )
               group by b.nro_con_cambio ;*/
           exception
              when no_data_found then
                 v_can_con_cambio:=0;
           end;

           if NVL(v_can_con_cambio,0) > 0 then
              p_error := 'Contrato de Cambios ya fué Liquidado. Nro: '||v_nro_con_cambio;
              return;
           end if;
        end if;
      else
        return;
      end if;
   end loop;
   -- Generar Movimientos Débito
   if p_error is null then
      for reg in c_deb loop
         pas_snp.pr_ini_registros;
         pas_snp.pr_ini_variables;
         rg_ge_snp_trans.nro_referencia           := reg.nro_referencia;
         rg_ge_snp_trans.nro_sec_lote             := reg.nro_sec_lote;
         rg_ge_snp_trans.cod_modulo               := reg.cod_modulo;
         rg_ge_snp_trans.cod_modalidad            := reg.cod_modalidad;
         rg_ge_snp_trans.cod_oficina              := reg.cod_oficina;
         rg_ge_snp_trans.cod_tip_operacion        := reg.cod_tip_operacion;
         rg_ge_snp_trans.cod_sub_tip_operacion    := reg.cod_sub_tip_operacion;
         rg_ge_snp_trans.cod_msj_swift            := reg.cod_msj_swift;
         rg_ge_snp_trans.fec_recepcion            := reg.fec_recepcion;
         rg_ge_snp_trans.fec_ingreso              := reg.fec_ingreso;
         rg_ge_snp_trans.fec_valor                := reg.fec_valor;
         rg_ge_snp_trans.fecha                    := reg.fecha;
         rg_ge_snp_trans.hora                     := reg.hora;
         rg_ge_snp_trans.cod_usuario              := reg.cod_usuario;
         rg_ge_snp_trans.cod_moneda               := reg.cod_moneda;
         rg_ge_snp_trans.monto                    := reg.monto;
         rg_ge_snp_trans.cod_per_solicitante      := reg.cod_per_solicitante;
         rg_ge_snp_trans.nom_solicitante          := reg.nom_solicitante;
         rg_ge_snp_trans.dir_solicitante          := reg.dir_solicitante;
         rg_ge_snp_trans.nro_doc_solicitante      := reg.nro_doc_solicitante;
         rg_ge_snp_trans.nro_cta_solicitante      := reg.nro_cta_solicitante;
         rg_ge_snp_trans.cod_swi_pte_solicitante  := reg.cod_swi_pte_solicitante;
         rg_ge_snp_trans.nro_cta_pte_solicitante  := reg.nro_cta_pte_solicitante;
         rg_ge_snp_trans.cod_per_beneficiario     := reg.cod_per_beneficiario;
         rg_ge_snp_trans.nom_beneficiario         := reg.nom_beneficiario;
         rg_ge_snp_trans.dir_beneficiario         := reg.dir_beneficiario;
         rg_ge_snp_trans.nro_doc_beneficiario     := reg.nro_doc_beneficiario;
         rg_ge_snp_trans.nro_cta_beneficiario     := reg.nro_cta_beneficiario;
         rg_ge_snp_trans.cod_swi_pte_beneficiario := reg.cod_swi_pte_beneficiario;
         rg_ge_snp_trans.nro_cta_pte_beneficiario := reg.nro_cta_pte_beneficiario;
         rg_ge_snp_trans.concepto                 := reg.concepto;
         rg_ge_snp_trans.observacion              := reg.observacion;
         rg_ge_snp_trans.tip_cargo                := reg.tip_cargo;
         rg_ge_snp_trans.ind_valor                := reg.ind_valor;
         rg_ge_snp_trans.nro_ref_externa          := reg.nro_ref_externa;
         rg_ge_snp_trans.situacion                := reg.situacion;
         rg_ge_snp_trans.estado                   := reg.estado;
         rg_ge_snp_trans.prioridad                := reg.prioridad;
         rg_ge_snp_trans.nro_operacion            := reg.nro_operacion;
         rg_ge_snp_trans.tip_mensaje              := reg.tip_mensaje;
         rg_ge_snp_trans.error                    := reg.error;
         rg_ge_snp_trans.origen                   := reg.origen;
         rg_ge_snp_trans.plataforma               := reg.plataforma;
         rg_ge_snp_trans.indemnizado              := reg.indemnizado;
         rg_ge_snp_trans.cod_per_intermediario    := reg.cod_per_intermediario;
         rg_ge_snp_trans.nom_intermediario        := reg.nom_intermediario;
         rg_ge_snp_trans.cod_swi_pte_intermediario:= reg.cod_swi_pte_intermediario;
         rg_ge_snp_trans.dir_intermediario        := reg.dir_intermediario;
         rg_ge_snp_trans.nro_cta_pte_intermediario:= reg.nro_cta_pte_intermediario;
         rg_ge_snp_trans.cod_bco_corresponsal     := reg.cod_bco_corresponsal;
         rg_ge_snp_trans.nom_corresponsal         := reg.nom_corresponsal;
         rg_ge_snp_trans.cod_swi_pte_corresponsal := reg.cod_swi_pte_corresponsal;
         rg_ge_snp_trans.nro_cta_pte_corresponsal := reg.nro_cta_pte_corresponsal;
         rg_ge_snp_trans.cod_tra_padre            := 302;

      --Si es para hoy hago movimiento y envio
      v_est_periodo:= nvl(pas_snp.fu_obt_est_horario(rg_ge_snp_trans.cod_msj_swift, rg_ge_snp_trans.cod_tip_operacion, rg_ge_snp_trans.cod_sub_tip_operacion),'C');
      if ((v_est_periodo = 'A') and
          (fug_den_per_act_snp(rg_ge_snp_trans.cod_msj_swift, rg_ge_snp_trans.cod_tip_operacion, rg_ge_snp_trans.cod_sub_tip_operacion,rg_ge_snp_trans.cod_tra_padre,3) = 'S')) then
           v_est_periodo := 'C';
      end if;

      /*
    if rg_ge_snp_trans.fec_valor = pag_cal.FU_OBT_FEC_ACTUAL(1)
         and v_est_periodo <> 'A' then
         --Si el periodo esta cerrado no se hace nada
          p_error := 'Periodo de Sipap Cerrado - No se puede enviar mensajeria';
          return;
      end if;
    */
      if rg_ge_snp_trans.fec_valor = pag_cal.FU_OBT_FEC_ACTUAL(1)
         --wa: El periodo debe estar abierto para intentar envio
         and v_est_periodo='A' then
         begin
            -- OMM 07/01/2015 Se Agrega Tra Padre para identificar el movimiento
           -- pas_snp.pr_pro_transferencia(rg_ge_snp_trans, 302);
        if pas_snp.fu_obt_cod_error <> 0 then
           p_error := 'Error :'||pas_snp.fu_obt_msj_error;
           return;
        end if;
              pas_snp.pr_set_transferencias(rg_ge_snp_trans);
              if pas_snp.fu_obt_cod_error <> 0 then
                 p_error := 'Error :'||pas_snp.fu_obt_msj_error;
                 return;
              end if;
        if pas_snp.fu_ver_mov_duplicados(rg_ge_snp_trans) > 0 then
           pas_snp.pr_ini_workflow(rg_ge_snp_trans);
           rg_ge_snp_trans.estado := 'S';
           pas_snp.pr_set_transferencias(rg_ge_snp_trans);
     if pas_snp.fu_obt_cod_error <> 0 then
                    p_error := 'Error :'||pas_snp.fu_obt_msj_error;
                    return;
                 end if;
        end if;
            exception
                 when others then
                        p_error := 'Error :'||pas_snp.g_msj_error;
                   return;
            end;
            if pas_snp.g_cod_error != 0 then
               p_error := pas_snp.g_msj_error;
               return;
            else
              --Sino hubo error, actualizamos la 503 para Nro_Documento3
              begin

              update ge_movimientos
                   set nro_documento3 = p_cod_ente
               where fecha = pag_cal.FU_OBT_FEC_ACTUAL(1)
                 and cod_usuario = p_usuario
              -- and hora = rg_ge_snp_trans.hora
                 and nro_documento=rg_ge_snp_trans.nro_referencia
                 and reversado ='N'
             --  and nro_secuencia = 1
                 and cod_transaccion= 503;
                exception
                      when others then
                        p_error := 'Error Mov.REf.:'||rg_ge_snp_trans.nro_referencia||' Hora:'||rg_ge_snp_trans.hora|| ' '||sqlerrm;
                        return;
                end;

            end if;
      end if;
      end loop;
      else
        return;
      end if;
--
   -- Enviar Swift 103 --
   if p_error is null
     and p_cod_ente is not null
        and p_usuario is not null
           and p_fec_pago is not null
              and p_nro_archivo is not null then
       pas_snp.pr_gen_men_pag_proveedor( p_cod_ente,
                                         p_usuario,
                                         p_fec_pago,
                                         p_nro_archivo );
   else
     return;
   end if;
--

   --Para procesar los 102 y los 103 del día(futuras) en cola
   --Todos los periodos se abren y cierran juntos, solo si esta abierto
   --se llama a mensajera automatica
  /* if nvl(v_est_periodo,'C') = 'A' then
      pas_snp.pr_gen_men_automaticos;
   end if;*/


EXCEPTION
   when others then
     if p_error is null then
       p_error := substr('ERROR EN LA GENERACION DE TRANSFERENCIAS: '||sqlerrm, 1, 1000);
       return;
     else
       return;
     end if;
END PR_PRO_PAG_SNP;
/* Procedimiento para validar un contrato de cambio */
PROCEDURE PR_VAL_NRO_CONTRATO(p_nro_contrato    IN OUT NUMBER,
                              p_cod_persona     IN ba_personas.cod_persona%TYPE,
                              p_mto_credito     IN NUMBER,
                              p_cod_mon_debito  IN ba_monedas.cod_moneda%TYPE,
                              p_cod_mon_credito IN ba_monedas.cod_moneda%TYPE,
                              p_ope_homebanking IN VARCHAR2,
                              p_cod_mensaje     IN OUT NUMBER,
                              p_mensaje         IN OUT VARCHAR2,
                              p_mto_debito      IN OUT NUMBER) IS
  v_tip_operacion lc_ope_pendientes.cod_tip_operacion%TYPE;
  v_mto_debito    lc_ope_pendientes.monto%TYPE;
  v_mto_credito   lc_ope_pendientes.monto%TYPE;
  v_lc_cod_moneda lc_ope_pendientes.cod_moneda%TYPE;
  v_cod_mon_local ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local();
  g_cod_error     NUMBER := 73;
BEGIN
  IF to_char(SYSDATE, 'HH24:MI') NOT BETWEEN to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_INICIO', 7, 71), 'HH24:MI'), 'HH24:MI')
      AND to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_FIN', 7, 71),'HH24:MI'),'HH24:MI') THEN
      p_cod_mensaje := g_cod_error;
      p_mensaje:= 'Hora cerrada para contrato';
      RETURN;
  END IF;
  -- Se verifica el contrato de cambio
  if p_cod_mon_debito = v_cod_mon_local then
     v_tip_operacion := 30; -- Venta de Divisas
  else
     v_tip_operacion := 16; -- Compra de Divisas
  end if ;
  begin
     SELECT decode(l.cod_moneda, p_cod_mon_debito, l.monto, l.mto_equ_local) Mto_Debito,
            decode(l.cod_moneda, p_cod_mon_debito, l.mto_equ_local, l.monto) Mto_Credito,
            l.cod_moneda, l.nro_operacion
       INTO v_mto_debito, v_mto_credito, v_lc_cod_moneda, p_nro_contrato
       FROM lc_ope_pendientes l
      WHERE l.cod_tip_operacion = v_tip_operacion
        AND (l.nro_operacion = p_nro_contrato OR l.nro_diario = p_nro_contrato)
        AND l.liquidado = 'N'
        AND l.ope_homebanking = p_ope_homebanking
        AND l.cod_persona = p_cod_persona
        AND TRUNC(l.fec_operacion) = TRUNC(SYSDATE);
  EXCEPTION
     WHEN OTHERS THEN
        p_cod_mensaje := g_cod_error;
        p_mensaje := 'NUMERO DE CONTRATO INVALIDO.';
        RETURN;
  END;
  -- No se puede realizar arbitraje por contrato
  IF p_cod_mon_debito <> v_cod_mon_local and p_cod_mon_credito <> v_cod_mon_local then
     p_cod_mensaje := g_cod_error;
     p_mensaje := 'NUMERO DE CONTRATO INVALIDO(MONEDA).';
     RETURN;
  END IF;
  -- Si es una venta la moneda de debito debe ser guaranies y la moneda de credito tiene que ser igual al contrato de cambio
  IF v_tip_operacion=30 AND NOT ( p_cod_mon_debito = v_cod_mon_local and v_lc_cod_moneda = p_cod_mon_credito) THEN
     p_cod_mensaje := g_cod_error;
     p_mensaje := 'CONTRATO INVALIDO, MONEDA NO COINCIDE.';
     RETURN;
  END IF;
  --Si es una compra la moneda de debito tiene que ser la moneda del contrato y la de credito tiene que ser guaranies
  IF v_tip_operacion=16 AND NOT (p_cod_mon_debito = v_lc_cod_moneda AND v_cod_mon_local = p_cod_mon_credito) THEN
     p_cod_mensaje := g_cod_error;
     p_mensaje := 'CONTRATO INVALIDO, MONEDA NO COINCIDE.';
     RETURN;
  END IF;
  IF v_mto_credito <> p_mto_credito THEN
     p_mensaje := 'MONTO DE CONTRATO INVALIDO.';
     p_cod_mensaje := 64;
     RETURN;
  END IF;
  p_mto_debito  := v_mto_debito;
END PR_VAL_NRO_CONTRATO;

 /* Obtiene la fecha snp de un periodo */
 FUNCTION FU_OBT_FEC_SNP(P_COD_PERIODO IN GE_SNP_HORARIOS.COD_PERIODO%TYPE) RETURN DATE IS
   v_retorno ge_snp_horarios.fecha%TYPE;
 BEGIN
    SELECT h.fecha
      INTO v_retorno
      FROM ge_snp_horarios h
     WHERE h.cod_periodo = p_cod_periodo;

    RETURN v_retorno;
 EXCEPTION
   WHEN OTHERS THEN
     RETURN NULL;
 END FU_OBT_FEC_SNP;

  /* Obtiene la cantidad de operaciones de cambio de un lote de pago*/
 FUNCTION FU_OBT_CAN_OPE_CAMBIO(P_COD_ENTE    IN GE_PAG_PROVEEDORES.COD_ENTE%TYPE,
                                P_FEC_PAGO    IN GE_PAG_PROVEEDORES.FEC_PAGO%TYPE,
                                P_COD_MONEDA  IN GE_PAG_PROVEEDORES.COD_MONEDA%TYPE,
                                P_NRO_ARCHIVO IN GE_PAG_PROVEEDORES.NRO_ARCHIVO%TYPE,
                                P_TEMPORAL    IN VARCHAR2 DEFAULT 'N') RETURN NUMBER IS
   v_retorno NUMBER;
 BEGIN
   IF nvl(P_TEMPORAL, 'N') = 'N' THEN
      SELECT COUNT(0)
        INTO v_retorno
        FROM ge_pag_proveedores gp
       WHERE gp.cod_ente = p_cod_ente
         AND gp.estado = 'C'
         AND gp.for_pago = 'I'
         AND gp.cod_moneda <> p_cod_moneda
         AND gp.nro_archivo = p_nro_archivo
         AND gp.fec_pago = p_fec_pago
         AND trunc(gp.fec_insercion) = trunc(SYSDATE);
   ELSE
      SELECT COUNT(0)
        INTO v_retorno
        FROM ge_pag_proveedores_tmp gp
       WHERE gp.cod_ente = p_cod_ente
         AND gp.estado = 'C'
         AND gp.for_pago = 'I'
         AND gp.cod_moneda <> p_cod_moneda
         AND gp.nro_archivo = p_nro_archivo
         AND gp.fec_pago = p_fec_pago
         AND trunc(gp.fec_insercion) = trunc(SYSDATE);
   END IF;
   RETURN v_retorno;
 EXCEPTION
   WHEN OTHERS THEN
     RETURN 0;
 END FU_OBT_CAN_OPE_CAMBIO;

  /* Cambiar la hora de pago SIPAP */
 FUNCTION FU_CAM_FEC_PAGO(P_COD_ENTE    IN GE_PAG_PROVEEDORES.COD_ENTE%TYPE,
                          P_FEC_PAGO    IN OUT GE_PAG_PROVEEDORES.FEC_PAGO%TYPE,
                          P_NRO_ARCHIVO IN OUT GE_PAG_PROVEEDORES.NRO_ARCHIVO%TYPE,
                          P_TEMPORAL    IN VARCHAR2 DEFAULT 'N',
                          P_FEC_INSERCION IN DATE DEFAULT SYSDATE) RETURN BOOLEAN IS
    v_fec_pag     DATE := p_fec_pago;
    v_nro_archivo NUMBER := p_nro_archivo;
    v_retorno     BOOLEAN := FALSE;
 BEGIN
   p_fec_pago := pag_cal.FU_OBT_FEC_HABIL(p_fec_pago + 1,1,1);
   p_nro_archivo := fu_obt_nro_secuencia(p_cod_ente, p_fec_pago);

   -- se cambia la fecha de pago al dia habil siguiente
   IF nvl(P_TEMPORAL, 'N') = 'N' THEN
      UPDATE ge_pag_proveedores gp
         SET gp.fec_pago = p_fec_pago,
             gp.nro_archivo = p_nro_archivo
       WHERE gp.cod_ente = p_cod_ente
         AND gp.estado = 'C'
         AND gp.tip_carga = 'H'
         AND gp.fec_pago = v_fec_pag
         AND gp.nro_archivo = v_nro_archivo
         AND trunc(gp.fec_insercion) = trunc(sysdate);
   ELSE
      UPDATE ge_pag_proveedores_tmp gp
         SET gp.fec_pago = p_fec_pago,
             gp.nro_archivo = p_nro_archivo
       WHERE gp.cod_ente = p_cod_ente
         AND gp.estado = 'C'
         AND gp.tip_carga = 'H'
         AND gp.fec_pago = v_fec_pag
         AND gp.nro_archivo = v_nro_archivo
         AND trunc(gp.fec_insercion) = trunc(p_fec_insercion);
   END IF;
   -- si se cambia la fecha hay que ver si hay monedas distintas
   IF SQL%ROWCOUNT > 0 THEN
      v_retorno := TRUE;
   END IF;
   RETURN v_retorno;
 EXCEPTION
   WHEN OTHERS THEN
     RETURN FALSE;
 END FU_CAM_FEC_PAGO;

 /* verificar lotes de pagos  */
 PROCEDURE PR_VER_OPERACIONES IS
    v_fec_actual     ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(4);
    v_cod_tra_padre  ge_transacciones.cod_transaccion%TYPE;
    v_sum_pagado     ge_pag_proveedores.monto%type := 0;
    v_sum_pagado_snp ge_pag_proveedores.monto%type := 0;
    v_mto_total      ge_pag_proveedores.monto%type := 0;

    -- cursor de operaciones autorizadas por Homebanking
    CURSOR c_cab_homebanking IS
       SELECT trim(b.dato) dato, b.nro_documento, b.referencia nro_archivo,
              trim(substr(b.dato2,1,10)) fec_pago, b.nro_cuenta, b.tip_pago,
              b.monto
         FROM bw_mov_pendientes b
        WHERE b.cod_tip_mensaje = '075'
          AND to_date(substr(b.dato2,1,10),'DD/MM/YYYY') <= v_fec_actual
          AND b.estado IN ('C', 'E')
           AND EXISTS (select 1
                         from ge_pag_proveedores gp
                        where gp.cod_ente = trim(b.dato)
                          and gp.fec_pago = to_date(substr(b.dato2,1,10),'DD/MM/YYYY')
                          and gp.referencia = b.nro_documento
                          and gp.tip_carga = 'H'
                          and gp.estado in ('C', 'R')/*or   --- DYDMR-7951 Ago/2018
                               (gp.estado = 'N' and gp.for_pago = 'I' and gp.fec_pago = v_fec_actual)*/
                       );
 BEGIN
    FOR pr IN c_cab_homebanking LOOP
       v_cod_tra_padre := fug_obt_parentes(pr.dato, 'COD_TRA_PAD_PPROV');
      -- DYDMR-6345 OMM 24/04/2017 Se obtiene el monto ya pagado para validar el saldo.
       Begin
          select nvl(sum(a.monto), 0)
          into v_sum_pagado
           from ge_pag_proveedores a
          where a.cod_ente = pr.dato
           -- and a.fec_pago = to_date(pr.fec_pago, 'DD/MM/YYYY')
            and a.nro_cta_debito = pr.nro_cuenta  --DYDMR-7024 JUL/2017 No corresponde la fecha de pago
            and a.referencia = pr.nro_documento
            and a.estado = 'N'
            and a.hora is not null;
        exception
          WHEN OTHERS THEN
             v_sum_pagado := 0 ;
        end ;
        --DDSI-1665 - Pago a Proveedores - Operaciones Situación Error Procesadas Lote Mixto
        Begin
      select nvl(sum(a.monto), 0)
          into v_sum_pagado_snp
           from ge_pag_proveedores a, ge_snp_transferencias t
          where a.cod_ente = pr.dato
           and a.nro_cta_debito = pr.nro_cuenta
           and a.referencia = pr.nro_documento
           and a.nro_referencia = t.nro_referencia
           and t.situacion != 'P'
           and t.estado = 'A';
        exception
          WHEN OTHERS THEN
       v_sum_pagado_snp := 0;
        end ;
    v_sum_pagado := v_sum_pagado + v_sum_pagado_snp;
    v_mto_total := pr.monto - v_sum_pagado ;
       -- verificamos si se puede realizar la operación de débito
       IF paw_bce.fu_ver_operacion(pr.nro_cuenta, v_mto_total, 503, v_cod_tra_padre, 'D') = 'N' THEN
          -- controlamos si dispone de saldo suficiente
          IF nvl(pag_cta.g_cod_error, 0) IN (25, 29, 31, 36) THEN
             --DDSI-1665 - Pago a Proveedores - Operaciones Situación Error Procesadas Lote Mixto
             PAW_UTI.pr_insertarBitacora('999999','999','999999','999999','999999', substr('Error al procesar el pago a proveedores - PRG_PRO_PAG_PROVEDOR '|| ' - Ente:' || pr.dato || ' - Referencia:' || pr.nro_documento || ' - Fecha Pago:' || pr.fec_pago || ' - Numero cuenta:' || pr.nro_cuenta || ' - Tipo pago:' || pr.tip_pago || ' - Monto:' || pr.monto || ' - Suma pagado:' || v_sum_pagado || ' - Monto Total:' || v_mto_total || ' - Cod Error:' || pag_cta.g_cod_error,1,998),
                                                                   PAW_UTI.BITACORA_ERROR);
             -- notificar lote al ente y cancelar el mismo
             pr_can_lote(pr.dato, pr.fec_pago, pr.nro_archivo);
             pr_not_lote(pr.dato, pr.fec_pago, pr.nro_archivo, 'Se envia adjunto los siguientes lotes que no pudieron ser procesados en fecha '|| pr.fec_pago);
          END IF;
       END IF;
     v_sum_pagado_snp := 0;
       v_sum_pagado := 0 ;
       v_mto_total  := 0 ;
    END LOOP;
 EXCEPTION
   WHEN OTHERS THEN
     raise_application_error(-20001,'PAG_PRV.PR_VER_OPERACIONES-ent:'||sqlerrm);
 END PR_VER_OPERACIONES;

 /* cancelar lote de pago */
 PROCEDURE PR_CAN_LOTE(p_cod_ente    IN ge_pag_proveedores.cod_ente%TYPE,
                       p_fec_pago    IN ge_pag_proveedores.fec_pago%TYPE,
                       p_nro_archivo IN ge_pag_proveedores.nro_archivo%TYPE) IS
    CURSOR c_tra_snp IS
       SELECT p.nro_referencia
         FROM ge_pag_proveedores p
        WHERE p.cod_ente = p_cod_ente
          AND p.fec_pago = p_fec_pago
          AND p.nro_archivo = p_nro_archivo
          AND p.for_pago = 'I';
 BEGIN
    UPDATE ge_pag_proveedores p
       SET p.estado = 'A'
     WHERE p.cod_ente = p_cod_ente
       AND p.fec_pago = p_fec_pago
       AND p.nro_archivo = p_nro_archivo;

    FOR cu IN c_tra_snp LOOP
       UPDATE ge_snp_transferencias t
          SET t.situacion = 'E'
        WHERE t.nro_referencia = cu.nro_referencia;
    END LOOP;
 EXCEPTION
    WHEN OTHERS THEN
       raise_application_error(-20001,'PAG_PRV.PR_CAN_LOTE-ent:'||p_cod_ente||', fec:'||to_char(p_fec_pago, 'dd/mm/yyyy')||', arc:'||p_nro_archivo||sqlerrm);
 END PR_CAN_LOTE;

 /* Notificar lote de pago */
 PROCEDURE PR_NOT_LOTE(p_cod_ente    IN ge_pag_proveedores.cod_ente%TYPE,
                       p_fec_pago    IN ge_pag_proveedores.fec_pago%TYPE,
                       p_nro_archivo IN ge_pag_proveedores.nro_archivo%TYPE,
                       p_mensaje     IN VARCHAR2) IS

    v_dir_mail_deb    ge_par_entes.val_parametro%TYPE;
    v_ext_archivo     ge_par_entes.val_parametro%TYPE := 'xls';
    v_nom_cli_debito  ba_personas.nom_completo%TYPE;
    c_dir_mail        ba_personas.dir_correo%TYPE := fug_obt_pardinamico('CAN_MAR_DIR_MAIL');
    v_texto           VARCHAR2(4000);
    v_texto_detalle   CLOB;
    v_texto_detalle2  CLOB;
    v_texto_detalle3  CLOB;

    v_adjunto       CLOB;
    v_adjunto2      CLOB;
    v_adjunto3      CLOB;

    v_cabecera        CLOB;
    v_nom_adj         VARCHAR2(500);
    v_total_procesado NUMBER;
    v_can_facturas    NUMBER;
    v_nro_factura VARCHAR2(2000);

    -- Variables para mail
    v_conn     utl_smtp.connection;
    v_asunto   VARCHAR2(2000);
    v_mje_mail LONG;
    v_nro_pago VARCHAR2(200);
    v_db_name    VARCHAR2(20);

    --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
    -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
    v_membrete LONG := fug_gen_template('M')|| chr(10);
    V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
    V_PIE      LONG := chr(10) ||fug_gen_template('P');
    --

    CURSOR c_lote IS
       SELECT *
         FROM ge_pag_proveedores p
        WHERE p.cod_ente = p_cod_ente
          AND p.fec_pago = p_fec_pago
          AND p.nro_archivo = p_nro_archivo;

    FUNCTION lf_obt_banco(p_cod_banco IN NUMBER) RETURN VARCHAR2 IS
       v_retorno gv_snp_participantes.participante%TYPE;
    BEGIN
       IF nvl(p_cod_banco, 0) = 0 THEN
          v_retorno := fug_obt_pardinamico('NOM_BANCO');
       ELSE
          SELECT p.participante
            INTO v_retorno
            FROM gv_snp_participantes p
           WHERE (p.cod_banco = p_cod_banco OR p.cod_ente = p_cod_banco)
             AND ROWNUM = 1;
       END IF;
       RETURN v_retorno;
    EXCEPTION
       WHEN OTHERS THEN
          RETURN '';
    END;
 BEGIN
    v_dir_mail_deb   := fug_obt_parentes(p_cod_ente, 'DIR_MAIL_PP');

    -- obtenemos el nombre de la base para control
    SELECT upper(sys_context('USERENV', 'DB_NAME'))
      INTO v_db_name
      FROM dual;

      -- controlamos el envio de correo
    IF fug_ind_produccion <> 'S' AND nvl(v_dir_mail_deb, 'x') <> fug_obt_pardinamico('TST_NOT_MAIL') THEN
       RETURN;
    END IF;

    v_nom_cli_debito := fue_obt_nom_ente(p_cod_ente);

    v_texto_detalle   := NULL;
    v_texto_detalle2  := NULL;
    v_texto_detalle3  := NULL;
    v_adjunto         := NULL;
    v_adjunto2        := NULL;
    v_adjunto3        := NULL;
    v_total_procesado := 0;
    v_can_facturas    := 0;

    FOR b IN c_lote LOOP

       IF b.tip_carga = 'H' THEN
          v_nro_factura := nvl(b.ref_facturas, b.nro_factura);
       ELSE
          v_nro_factura := b.nro_factura;
       END IF;

       v_total_procesado := v_total_procesado + nvl(b.monto, 0);

       v_can_facturas := v_can_facturas + 1;
       v_nro_pago := p_nro_archivo;

       IF v_can_facturas <= 300 THEN
          v_adjunto := v_adjunto || nvl(b.nro_cta_credito, b.nro_cta_beneficiario) || chr(9) || lf_obt_banco(b.ent_bca_beneficiario) || chr(9) || v_nro_factura || chr(9) || b.cod_moneda || chr(9) || b.monto || chr(9) || v_nro_pago || chr(9) || chr(10);
       ELSIF v_can_facturas BETWEEN 301 AND 600 THEN
          v_adjunto2 := v_adjunto2 || nvl(b.nro_cta_credito, b.nro_cta_beneficiario) || chr(9) || lf_obt_banco(b.ent_bca_beneficiario) || chr(9) || v_nro_factura || chr(9) || b.cod_moneda || chr(9) || b.monto || chr(9) || v_nro_pago || chr(9) || chr(10);
       ELSE
          v_adjunto3 := v_adjunto3 || nvl(b.nro_cta_credito, b.nro_cta_beneficiario) || chr(9) || lf_obt_banco(b.ent_bca_beneficiario) || chr(9) || v_nro_factura || chr(9) || b.cod_moneda || chr(9) || b.monto || chr(9) || v_nro_pago || chr(9) || chr(10);
       END IF;

    END LOOP;

    IF v_adjunto IS NOT NULL THEN
       v_cabecera := 'Cuenta de crédito' || chr(9) || 'Banco' || chr(9) || 'Nro. Factura' || chr(9) || 'Moneda' || chr(9) || 'Monto' || chr(9) || 'Nro. Pago' || chr(9) /*|| chr(10)*/;

       IF v_adjunto2 IS NULL AND v_adjunto3 IS NULL THEN

          v_texto_detalle := v_cabecera || chr(10) || v_adjunto || chr(10) || chr(9) || chr(9) || chr(9) || 'Total :' || chr(9) || v_total_procesado || chr(10);

       ELSIF v_adjunto2 IS NOT NULL AND v_adjunto3 IS NULL THEN
          v_texto_detalle := v_cabecera || chr(10) || v_adjunto;

          v_texto_detalle2 := v_adjunto2 || chr(10) || chr(9) || chr(9) || chr(9) || 'Total :' || chr(9) || v_total_procesado || chr(10);
       ELSE
          v_texto_detalle := v_cabecera || chr(10) || v_adjunto;

          v_texto_detalle2 := v_adjunto2;

          v_texto_detalle3 := v_adjunto3 || chr(10) || chr(9) || chr(9) || chr(9) || 'Total :' || chr(9) || v_total_procesado || chr(10);
       END IF;
    END IF;

    v_texto := '<br><br>
               <br><br>
                 Estimado Cliente: ' || upper(v_nom_cli_debito) || '
               <br><br> ' ||
              p_mensaje ||
               ' <br><br>
                 Atentamente.
               <br><br>
               <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
               <br><br>
               <br><br>';

    v_nom_adj := 'BBVA_PAG_PROV_' || p_cod_ente || '_' || to_char(p_fec_pago, 'DDMMYY') || '_' || v_nro_pago;

    v_asunto   := 'Pago a Proveedores';
    v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto || chr(10) || chr(10) || chr(10) || V_FIN || chr(10) || V_PIE;

    IF v_dir_mail_deb IS NOT NULL THEN

       BEGIN

          v_conn := it_mail.begin_mail(c_dir_mail, v_dir_mail_deb, v_asunto, IT_MAIL.MULTIPART_MIME_TYPE);

          it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

          it_mail.begin_attachment(v_conn, 'text/plain', FALSE, v_nom_adj || '.' || v_ext_archivo);

          v_texto_detalle := chr(10) || CHR(9) || CHR(9) || 'SERVICIO DE PAGOS A PROVEEDORES' || CHR(10) ||
                             chr(10) || CHR(9) || 'CLIENTE' || CHR(9) || v_nom_cli_debito ||
                             chr(10) || CHR(9) || 'FECHA PAGO' || CHR(9) || to_char(p_fec_pago, 'DD/MM/YYYY') || CHR(10) ||
                             chr(10) || v_texto_detalle;

          it_mail.write_text(v_conn, v_texto_detalle);

          IF v_texto_detalle2 IS NOT NULL THEN
             it_mail.write_text(v_conn, v_texto_detalle2);
          END IF;
          IF v_texto_detalle3 IS NOT NULL THEN
             it_mail.write_text(v_conn, v_texto_detalle3);
          END IF;

          it_mail.end_mail(v_conn);

       EXCEPTION
          WHEN OTHERS THEN
             INSERT INTO tm_mails
                (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
             VALUES
                (c_dir_mail, v_dir_mail_deb, v_asunto, v_texto, SYSDATE, USER);
       END;
    END IF;
 EXCEPTION
    WHEN OTHERS THEN
       raise_application_error(-20001,'PAG_PRV.PR_NOT_LOTE-ent:'||p_cod_ente||', fec:'||to_char(p_fec_pago, 'dd/mm/yyyy')||', arc:'||p_nro_archivo||sqlerrm);
 END PR_NOT_LOTE;
 /*verifica los datos del tmp y procesa si no hay errores*/
 --NVB-2232
/*verifica los datos del tmp y procesa si no hay errores*/
PROCEDURE PR_VER_DAT_TMP_DEV
(p_cod_ente in ge_entes.cod_ente%type,
 p_fec_pago1 in date,
 p_fec_pago2 in date,
 p_error out varchar2,
 p_procesar in varchar2,
 p_nro_documento in number default null,
 p_nro_cta_debito in ge_cuentas.nro_cuenta%type default null,
 p_nro_archivo in number default null,
 p_fec_insercion in date default null -- Modificaciones Fecha de Pago a Proveedores
 ) IS

  v_cod_proceso     number(3) := 0;
  v_cant            number(5);
  v_cantidad        number(10);

  v_cod_modulo      ge_transacciones.cod_modulo%type;
  v_cod_modalidad   ge_transacciones.cod_modalidad%type;
  v_cod_moneda      ah_cta_vistas.cod_moneda%type;
  v_nro_cuenta      ge_cuentas.nro_cuenta%type;
  v_estado          ah_cta_vistas.estado%type;
  v_cta_combinada   ah_cta_vistas.cta_combinada%type;
  v_cod_mon_credito ah_cta_vistas.cod_moneda%type;

  v_concepto         ge_pag_proveedores_tmp.concepto%type;
  v_fec_pago         date;
  v_nombre           varchar2(50);
  v_fec_actual       ge_calendarios.fec_actual%type := trunc(sysdate);--pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_descripcion      ge_entes.descripcion%type;
  v_tip_comprobante  ge_pag_proveedores.tip_comprobante%type;
  v_cod_tra_padre    ge_transacciones.cod_transaccion%type;
  v_cta_debito       ge_cuentas.nro_cuenta%type;
  v_cod_rubro        cb_rubros.cod_rubro%type;
  v_pag_atrasada     ge_pag_proveedores.tip_carga%type;
  v_ref_archivo      ge_archivos.referencia%type;
  v_cod_tra_debito   ge_transacciones.cod_transaccion%type;
  v_todetal  number(18,2);
  v_tocabec  number(18,2);
  v_cod_oficina      ba_oficinas.cod_oficina%type;
  v_existe           varchar2(1);
  v_nom_persona      ba_personas.nom_completo%type;
  v_tot_factura      number(18,2);
  v_can_duplicado    number(10) ;
  v_redondeo         number (8);
  v_hab_snp          varchar2(1);
  v_mto_max_ach      number(18,2);
  v_hor_snp_abierto  varchar2(1);
  v_fec_insercion    date :=p_fec_insercion;
  v_ind_valor        varchar2(1);
  v_ope_homebanking  varchar2(1) := 'N';
  v_can_usd          number(5);
  v_tip_carga      varchar2(1);
  v_cli_pue_enviar   varchar2(1);
  v_user             ba_usuarios.cod_usuario%TYPE := substr(user,  1, 10);

  cursor c_tmp is
    select *
      from ge_pag_proveedores_tmp
     where trunc(fec_insercion) = trunc(nvl(v_fec_insercion,v_fec_actual)) -- Mod.Fec.Pago Prov.
       and usu_insercion = v_user
       and (cod_ente = p_cod_ente or cod_ente is null)
       and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
       for update;

  cursor c_fac(p_nro_orden number) is
    select *
      from ge_pag_pro_facturas_tmp
     where trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
       and nro_orden = p_nro_orden
       and usu_insercion = v_user
       and (cod_ente = p_cod_ente or cod_ente is null)
       and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

/* calcular fecha de pago a proveedores */
FUNCTION fl_cal_fec_pago
(p_beneficiario in varchar2,
 p_nom_persona  in varchar2 )
RETURN date IS

v_fec_pago DATE := nvl(v_fec_insercion,v_fec_actual) + 1;--x defecto el día siguiente

BEGIN
  --si carga ambas fechas dividir en dos grupos
  if p_fec_pago1 is not null and p_fec_pago2 is not null then
    IF UPPER(SUBSTR(LTRIM(nvl(p_beneficiario,p_nom_persona)),1,1)) BETWEEN 'A' AND 'H' THEN
      v_fec_pago := p_fec_pago1;
    ELSE
      v_fec_pago := p_fec_pago2;
    END IF;
  elsif p_fec_pago1 is not null then --sino todo se paga en el mismo día
      v_fec_pago := p_fec_pago1;
  end if;
  --buscar siguiente día hábil si es feriado o no hábil
  v_fec_pago := pag_cal.FU_OBT_FEC_HABIL(v_fec_pago, 1, v_cod_oficina);

  RETURN v_fec_pago;
EXCEPTION
  WHEN OTHERS THEN
    p_error := 'Error al calcular fecha de pago '||sqlerrm;
END;
/* principal */
BEGIN
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  --recupera oficina del usuario
  begin
    select cod_oficina
      into v_cod_oficina
      from ba_usuarios
     where cod_usuario = user;
  exception
    when others then
      p_error := 'Recup.oficina del usuario '||sqlerrm;
      return;
  end;
  --recupera parámetros del ente.
  pag_prv.PR_OBT_DAT_PROVEEDOR(p_cod_ente, v_descripcion, v_tip_comprobante, v_cod_tra_padre, v_cta_debito,
                              v_pag_atrasada, v_ref_archivo, v_cod_tra_debito,v_cod_rubro);

  -- CR 03/09/2012 se agrega por opción de poder pagar con más de una cuenta
  if p_nro_cta_debito is not null then
     v_cta_debito := p_nro_cta_debito;
     v_ope_homebanking := 'S';
  end if;
  --
  begin
     v_mto_max_ach :=to_number(fug_obt_pardinamico('MTO_MAX_ACH'));
  exception
     when others then
        null;
  end;
  -- verifico el horario sipap
  v_hor_snp_abierto := lf_obt_hor_snp;

  -- Verifico la cuenta de débito
  if  v_cta_debito is not null then
    pag_cta.PR_OBT_CUENTA(v_Cta_debito);
    if pag_cta.fu_obt_cod_error() <> 0 then
      p_error := 'Recup.Cta.Debito '||pag_cta.fu_obt_msj_error();
      return;
    end if;
    v_cod_moneda := pag_cta.g_ctas.cod_moneda;
    v_estado     := pag_cta.g_ctas.estado;
    v_cod_modulo := pag_cta.G_CTAS.cod_modulo;
    v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
    v_cta_combinada := pag_cta.g_ctas.cta_combinada;

    -- CR para control de decimales
    -- v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
    --

    if v_cod_modalidad not in (31,41) then
      p_error     := 'Modalidad Cta Debito no corresponde';
      return;
    --elsif v_cod_modalidad = 31 and v_cta_combinada = 'S' then
     -- p_error     := 'Cta Debito de Ahorro es combinada';
      --return;
    end if;
    if v_estado in ('A','C','T','D','I') then
      p_error     := 'Estado de Cta Debito invalido';
      return;
    end if;
  End if;

  if FUG_OBT_PER_ENTIDAD <> FUE_OBT_PER_ENTE(p_cod_ente) then -- DYDMR-96. CB. 12/12/2013
    --actualiza los datos básicos del tmp para poder verificar, solo si no actualizo antes
    begin
      if user in ('HBANK', 'BBVAAPIUSR') then
       v_tip_carga := 'H';
       v_user := 'HBANK';
      else
       select decode(nvl(PAE_CNF.G_PROGRAMA,'X'),'X','H','A')
        into v_tip_carga
        from dual;
      end if;
       update ge_pag_proveedores_tmp set
           tip_comprobante    = v_tip_comprobante,
           estado             = 'C',        --- cargado
           cod_usu_operador   = user,
           cod_ente           = p_cod_ente,
           tip_carga          = v_tip_carga,
           nro_cta_debito     = v_cta_debito
        where trunc(fec_insercion) = trunc(nvl(v_fec_insercion,v_fec_actual))
         and usu_insercion = v_user --por el usuario
         and (cod_ente = p_cod_ente or cod_ente is null)
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
        /*if sql%notfound then    --para el reproceso
          p_error := 'No existe registro a actualizar en TMP de proveedores.';
          return;
        end if; */
    exception
       when others then
          p_error := 'Actualizar TMP de proveedores.'||sqlerrm;
          return;
    end;
  end if;
  --verifica q haya datos
  for reg in c_tmp loop
    v_existe := 'S';
    exit;
  end loop;
  if v_existe is null then
    p_error := 'No existen datos cargados en el tmp. Verifique';
    return;
  end if;
  --proyecto pago a proveedores
  -- Verifico que no existan lotes mixtos en horario cerrado SIPAP
 /* select count(*)
    into v_cant
    from(
          select decode(for_pago, 'I', 'I', 'X'), count(0)
            from ge_pag_proveedores_tmp
           where trunc(fec_insercion) = trunc(sysdate)
             and usu_insercion = v_user
             and cod_ente = p_cod_ente
             and nvl(tipo,'C') = 'C'
             and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
           group by decode(for_pago, 'I', 'I', 'X')
         );

   if v_cant = 2 and v_hor_snp_abierto = 'N' and trunc(p_fec_pago1) = trunc(sysdate) then --Mixto (interbancaria y otro)
      p_error := 'Horario SIPAP Cerrado, no se puede procesar archivo Mixto';
      return;
   end if;*/

   --MTOP SEP/2020 SDSIPAP247-1
   v_can_usd :=0;
   begin
     select count(*)
      into v_can_usd
      from ge_pag_proveedores_tmp
       where trunc(fec_insercion) = trunc(sysdate)
         and usu_insercion = v_user
         and cod_ente = p_cod_ente
         and nvl(tipo,'C') = 'C'
         and for_pago = 'I'  -- Interbancarias
         and cod_moneda <>  'GS'
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
   exception
      when no_data_found then
           v_can_usd :=0;
   end;
  v_hab_snp := upper(substr(trim(fug_obt_parentes(p_cod_ente, 'SNP_HAB_PROVEEDORES')), 1, 1));

  --recorre los registros del temporal para verificar datos: cta.credito, forma de pago , etc
  for reg in c_tmp loop

    v_concepto     := reg.concepto;
    v_cod_proceso  := 0;

    if reg.for_pago is null then
       v_concepto    := 'DEBE INGRESAR UNA FORMA DE PAGO';
       v_cod_proceso := 82;
    end if;

    -- Verifico la cuenta de crédito
    if reg.for_pago = 'C' THEN -- crédito en cuenta
      if reg.nro_Cta_credito IS NULL THEN
         v_concepto := 'NO EXISTE CUENTA PARA EL CREDITO';
         v_cod_proceso := 66;
      else
        --limpiar variables
        v_cod_mon_credito := null;
        v_estado     := null;
        v_cod_modulo := null;
        v_cod_modalidad := null;
        v_cta_combinada := null;

        pag_cta.pr_obt_cuenta(reg.nro_cta_credito);
        if pag_cta.fu_obt_cod_error() <> 0 then
           v_concepto := substr(pag_cta.fu_obt_msj_error(),1,40);
           v_cod_proceso := 51;
        end if;
        v_cod_mon_credito := pag_cta.g_ctas.cod_moneda;
        v_estado     := pag_cta.g_ctas.estado;
        v_cod_modulo := pag_cta.G_CTAS.cod_modulo;
        v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
        v_cta_combinada := pag_cta.g_ctas.cta_combinada;
        --- si es cta ahorro o cta cte
         if v_cod_modalidad not in (31,41,334) THEN
            v_concepto     := 'MODALIDAD DE LA CUENTA INVALIDO';
            v_cod_proceso := 52;
         end if;
        if v_estado is null then
           v_concepto := 'ESTADO INVALIDO';
           v_cod_proceso := 53;
        end if;
       -- if v_cod_modalidad = 31 and v_cta_combinada = 'S' then
        --  v_concepto     := 'CUENTA COMBINADA P/AHORRO A LA VISTA';
         -- v_cod_proceso := 54;
        --end if;
        if v_estado IN ('C','T', 'P', 'X','B','I') THEN -- CR: se agrega pendiente de cancelación y verificación
          v_concepto     := 'ESTADO DE LA CUENTA INVALIDO';
          v_cod_proceso := 55;
        end if;
         if v_cod_moneda <> v_cod_mon_credito then
            -- Se elimina <> por caracter escapeado en homebanking ...
            v_concepto     := 'MONEDA CTA CREDITO INVALIDA';
            v_cod_proceso := 56;
         end if;

         if reg.cod_moneda is null then
            v_concepto    := 'MONEDA CREDITO NO ESPECIFICADA';
            v_cod_proceso := 81;
         end if;

         --DDSI-7 - GD - OCT/2017
         --Valido la moneda de credito con la moneda de la cuenta de débito del ente
         if reg.cod_moneda is not null then
           if v_cod_moneda <> reg.cod_moneda then
              v_concepto     := 'MONEDA NO CORRESPONDE A LA CTA CREDITO';
              v_cod_proceso := 58;
           end if;
         end if;

         -- CR: se verifica que la cuenta crédito no pertenezca al ente
         if v_cod_proceso = 0 and p_nro_cta_debito is not null then
           declare
             v_existe varchar2(1);
           begin
             select 'S'
               into v_existe
               from ge_cta_clientes cc, ge_entes ge
              where ge.cod_ente    = p_cod_ente
                and ge.cod_persona = cc.cod_persona
                and cc.nro_cuenta  = reg.nro_cta_credito;

             v_concepto    := 'CUENTA CREDITO PERTENECE AL ENTE';
             v_cod_proceso := 56;
           exception
             when others then
               v_existe := 'N';
           end;
         end if;
         --obtener principal de cuenta
         begin
           v_nom_persona := fue_obt_nom_persona(fug_obt_cli_principal(reg.nro_cta_credito));
         exception
           when others then
              if substr(sqlerrm,1,3)='ORA' then
                v_concepto  := substr(SQLERRM,12,40);
              ELSE
                v_concepto  := substr(SQLERRM,1,40);
              end if;
              v_cod_proceso :=57;
         end;
      END IF;--si tiene cta crédito
    end if; --- fin si forma de pago era en cta.crédito

  /*if reg.tip_comprobante not in ('F','O') then
      v_concepto := 'TIPO COMPROBANTE SOLO PUEDE SER F o O';
      v_cod_proceso := 59;
  end if;*/

    if reg.for_pago is not null and reg.for_pago not in ('C','G','E','R','I') then
      v_concepto := 'FORMA DE PAGO INVALIDA';
      v_cod_proceso := 60;
    end if;

    if reg.for_pago = 'G' AND reg.beneficiario IS NULL THEN
      v_concepto := 'BENEFICIARIO NO EXISTE P/CHEQUE GERENCIA';
      v_cod_proceso := 61;
    end if;

    if reg.for_pago = 'C' AND reg.nro_cta_credito IS NULL THEN
      v_concepto := 'NO EXISTE CUENTA PARA EL CREDITO';
      v_cod_proceso := 61;
    end if;
    if reg.for_pago = 'I' then
       v_ind_valor := nvl(reg.ind_valor, 'B');
    else
       v_ind_valor := null;
    end if;

    -- MTOP Jun/2020 cambia a Bajo Valor - MT102 si ya cerro sipap SDSIPAP247-1
    if nvl(v_can_usd,0) >= 0 then -- si tiene registros en USD es directo Alto Valor
       v_ind_valor := 'A';
    else
      if v_ind_valor ='A' and paw_bas.fu_obt_tip_TransfInterbancaria(103,'001','002',3302,reg.monto, reg.cod_moneda, null, fug_obt_cli_principal(p_nro_cta_debito) )='102' then
          v_ind_valor :='B';
      end if;
      v_cli_pue_enviar := fug_pue_env_tra_fue_hora(103,'001','002',3302,reg.monto, reg.cod_moneda, null, p_nro_cta_debito);
    end if;
    --
    if reg.ben_dir_correo is not null and v_cod_proceso = 0 then
       if paw_uti.fu_validarMail(reg.ben_dir_correo) = 'N' then
          v_concepto := 'DIRECCION DE CORREO INVALIDO';
          v_cod_proceso := 79;
       end if;
    end if;
    if reg.for_pago = 'I' and v_cod_proceso = 0 then
      if reg.concepto is null then
          v_concepto     := 'DEBE INGRESAR UN CONCEPTO';
          v_cod_proceso  := 80;
      end if;
      if nvl(v_hab_snp, 'N') = 'N' THEN
         v_concepto := 'CREDITO INTERBANCARIO INHABILITADO';
         v_cod_proceso := 61;
      elsif reg.cod_moneda is null then
         v_concepto := 'MONEDA CREDITO NO ESPECIFICADA';
         v_cod_proceso := 72;
      elsif reg.ind_valor = 'B' and reg.cod_moneda <> pag_gen.fu_obt_mon_local then
         v_concepto := 'PRIORIDAD INVALIDA, ACH SOLO PARA GS';
         v_cod_proceso := 72;
      elsif reg.monto > v_mto_max_ach and reg.ind_valor = 'B' then
         v_concepto := 'MONTO MAXIMO PARA ACH EXCEDIDO';
         v_cod_proceso := 64;
      elsif reg.cod_moneda <> v_cod_moneda and trunc(p_fec_pago1) > trunc(sysdate) then
            v_concepto := 'FECHA INVALIDA PARA OPERACION DE CAMBIO';
            v_cod_proceso := 76;
      /*elsif reg.cod_moneda <> v_cod_moneda and v_hor_snp_abierto = 'N' then
            v_concepto := 'HORA INVALIDA PARA OPERACION DE CAMBIO';
            v_cod_proceso := 76;*/
      --DDSI-7 - GD - OCT/2017
      elsif reg.cod_moneda <> v_cod_moneda and reg.nro_con_cambio is null then
            v_concepto := 'MONEDA DE CREDITO INVALIDA';
            v_cod_proceso := 72;
      elsif reg.nro_cta_beneficiario is null then
            v_concepto := 'NO EXISTE CUENTA INTERBANCARIA';
            v_cod_proceso := 66;
      elsif reg.nro_con_cambio is not null then
         declare
            v_mto_debito  lc_ope_pendientes.monto%TYPE;
            v_mto_credito lc_ope_pendientes.monto%TYPE;
         begin
            pr_val_nro_contrato(reg.nro_con_cambio,
                                fue_obt_per_ente(p_cod_ente),
                                reg.monto,
                                v_cod_moneda,
                                reg.cod_moneda,
                                v_ope_homebanking,
                                v_cod_proceso,
                                v_concepto,
                                v_mto_debito);
         end;
      elsif reg.cod_tip_doc_beneficiario is null then
         v_concepto := 'TIPO DOC. DEL BENEF. NO PUEDE SER NULO';
         v_cod_proceso := 74;
      elsif reg.nro_doc_beneficiario is null then
         v_concepto := 'DOCUMENTO DEL BENEF. NO PUEDE SER NULO';
         v_cod_proceso := 75;
      elsif reg.fec_pago - v_fec_actual > fug_obt_pardinamico('SNP_RAN_DIA_FEC_VALOR') then
         if reg.fec_pago != pag_cal.FU_OBT_FEC_HABIL(v_fec_actual + fug_obt_pardinamico('SNP_RAN_DIA_FEC_VALOR'), 1, v_cod_oficina) then
            v_concepto := 'FECHA DE PAGO ES MAYOR A '||fug_obt_pardinamico('SNP_RAN_DIA_FEC_VALOR')||' DIAS';
            v_cod_proceso := 76;
         end if;
      else
         -- verificamos si esta habilitado

         select count(*)
           into v_cant
           from gv_snp_participantes p
          where p.cod_swift =  reg.cod_swift
            --(p.cod_banco = reg.ent_bca_beneficiario or p.cod_ente = reg.ent_bca_beneficiario)
            and p.ind_hab_pte_hb = 'S'
            and p.cod_persona != fug_obt_per_entidad;

        if v_cant = 0 then
          --controla subparticipantes
           begin
               --Controla patrocinadores
                select count(*)
                  into v_cant
                  from ge_snp_patrocinador_det p
                 where p.cod_swift_sub = reg.cod_swift
                   and estado = 'S';
                   exception
                      when no_data_found then
                        v_cant:=0;
                      when others  then
                        v_cant:=0;
                 end;
        end if;
         if v_cant = 0 then
            v_concepto := 'ENTIDAD INEXISTENTE O INHABILITADA';
            v_cod_proceso := 78;
         else
           select count(0)
             into v_cant
             from ba_tip_documentos a
            where a.estado = 'A'
              and a.cod_tip_documento = reg.cod_tip_doc_beneficiario;
            if v_cant = 0 then
               v_concepto := 'TIPO DOC. DEL BENEF. INVALIDO';
               v_cod_proceso := 74;
            else
               if v_ind_valor = 'B' and reg.monto > v_mto_max_ach then--consultar con toppi ojo
                  v_ind_valor := 'A';
               end if;
            end if;
         end if;
      end if;
      -- DDSI-62 -- La prioridad de envío B (ACH) no está permitida para transferencias al BCP.
      if v_ind_valor = 'B' and reg.ent_bca_beneficiario = 1 then -- BCP
        v_concepto := 'PRIORIDAD ACH NO PERMITIDA PARA BCP';
        v_cod_proceso := 75;
      end if;
      if reg.nro_cta_beneficiario is not null and  fue_val_es_numerico(reg.nro_cta_beneficiario)='N' then
         v_concepto := 'NRO CUENTA BENEF. INVALIDO';
         v_cod_proceso := 76;
      end if;
    end if;
    if v_cod_proceso = 0 then
       if reg.beneficiario is null then
          if reg.for_pago = 'C' then
             v_concepto := 'NO EXISTE BENEFICIARIO PARA EL CREDITO';
          else
             v_concepto := 'NO EXISTE BENEF. PARA EL CREDITO SIPAP';
          end if;
          v_cod_proceso := 77;
       end if;
    end if;
    --calcular fecha de pago
    v_fec_pago := fl_cal_fec_pago(reg.beneficiario, v_nom_persona);
    if p_error is not null then
      exit;
    end if;

    if reg.nro_orden is null then
    v_concepto     := 'NO TIENE ORDEN PAGO';
    v_cod_proceso := 62; ---- no tiene nro. orden pago
    end if;

    if reg.nro_factura is null then
     v_concepto     := 'NO TIENE NRO. FACTURA';
     v_cod_proceso := 63; ---- no tiene nro. factura
    end if;

    if nvl(reg.monto,0) = 0 then
      v_concepto     := 'NO TIENE MONTO A PAGAR';
      v_cod_proceso := 64; ---- no tiene monto a pagar
    end if;
    -- CR 03/09/2012
    if nvl(reg.monto,0) < 0 then
      v_concepto    := 'MONTO INVALIDO';
      v_cod_proceso := 64; ---- no tiene monto a pagar
    end if;
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,reg.cod_moneda);
    if nvl(reg.monto,0) <> trunc(nvl(reg.monto,0), v_redondeo) then
      v_concepto    := 'MONEDA NO ADMITE DECIMAL';
      v_cod_proceso := 64; ---- no tiene monto a pagar
    end if;
    --
    --Valido la moneda del txt con la moneda de la cuenta de débito del ente
    if reg.for_pago != 'I' and reg.cod_mon_recibido <> v_cod_moneda then
      v_concepto := 'MONEDA NO CORESPONDE A LA CTA. DE DEBITO';
      v_cod_proceso := 69;
    end if;
    -- Acá ya hace los controles por cada factura que lee...
    if v_tip_comprobante = 'O' and v_cod_proceso = 0 then
      v_tot_factura := 0;
      For reg_f in c_fac(reg.nro_orden) loop
        if reg_f.nro_orden is null then
           v_concepto := 'No tiene Nro.de orden en Facturas';
           v_cod_proceso := 65;
           --return;
        end if;
        if reg_f.nro_factura is null then
           v_concepto := 'No tiene Nro.Factura en el detalle';
           v_cod_proceso := 66;
        end if;
        if nvl(reg_f.mto_total,0) = 0 then
           v_concepto := 'No tiene Monto la Factura';
           v_cod_proceso := 67;
        end if;
        -- CR 03/09/2012
        if nvl(reg_f.mto_total,0) < 0 then
           v_concepto    := 'Monto Invalido';
           v_cod_proceso := 64; ---- no tiene monto a pagar
        end if;

        if nvl(reg_f.mto_total,0) <> trunc(nvl(reg_f.mto_total,0), v_redondeo) then
           v_concepto    := 'Moneda no Admite Decimal';
           v_cod_proceso := 64; ---- no tiene monto a pagar
        end if;
        --
        --
        v_tot_factura := v_tot_factura + nvl(reg_f.mto_total,0);
      end loop;
      if v_tot_factura <> nvl(reg.monto,0) and v_cod_proceso = 0 then
         v_concepto := 'No coincide monto de Orden con Facturas';
         v_cod_proceso := 68;
      end if;
    end if;
    -- OMM 04/05/2011 Verificamos si hay duplicación de comprobante
    v_can_duplicado := 0 ;
    if v_tip_comprobante = 'F' and v_cod_proceso = 0 then
       Select count(*) into v_can_duplicado
       from ge_pag_pro_facturas pf
       where pf.nro_orden = reg.nro_orden
         and pf.nro_factura = reg.nro_factura
         and pf.cod_ente = p_cod_ente;
       if v_can_duplicado > 0 then
           v_concepto := 'Orden ya ingresada Anteriormente';
           v_cod_proceso := 70;
        end if ;
    end if ;
    -- verifica si no hay duplicacion de datos temporales
    v_can_duplicado := 0 ;
    if v_tip_comprobante = 'F' and v_cod_proceso = 0 then
       select count(0)
         into v_can_duplicado
         from ge_pag_proveedores_tmp t
        where t.nro_orden = reg.nro_orden
          and t.nro_factura = reg.nro_factura
          and t.cod_ente = p_cod_ente
          and (nvl(t.nro_archivo, 0) <> nvl(reg.nro_archivo, 0) or
               (nvl(t.nro_archivo, 0) = nvl(reg.nro_archivo, 0) and t.nro_secuencia <> reg.nro_secuencia )
              )
          and trunc(t.fec_insercion) = nvl(v_fec_insercion,v_fec_actual);--trunc(sysdate);
       if v_can_duplicado > 0 then
           v_concepto := 'Registro ya ingresado Anteriormente';
           v_cod_proceso := 70;
        end if ;
    end if;

    ---- actualiza los datos que faltan en el tmp antes de pasar a GE_PAG_PROVEEDORES

    begin
       update ge_pag_proveedores_tmp set
           fec_ingreso        = nvl(v_fec_insercion,v_fec_actual),
           --fec_pago           = decode(for_pago,'I', fec_pago, v_fec_pago),
           cod_proceso        = v_cod_proceso,
           concepto           = v_concepto,
           cod_moneda         = nvl(reg.cod_moneda,v_cod_moneda),
           referencia         = p_nro_documento,
           nro_cta_debito     = v_cta_debito,
           ind_valor          = v_ind_valor
        where current of c_tmp ;
        if sql%notfound then
          p_error := 'No encontro registro a actualizar en TMP de proveedores';
          exit;
        end if;
    exception
      when others then
         p_error := 'Al actualizar TMP de proveedores :'||sqlerrm;
         exit;
    end;
  end loop;
  if p_error is not null then
    return;
  end if;
  if v_tip_comprobante = 'O' then
    --* actualiza fecha de carga en tmp de facturas, SI ES QUE TIENE DETALLES
    begin
      update ge_pag_pro_facturas_tmp c
         set fec_carga  = (select fec_pago
                             from ge_pag_proveedores_tmp g
                            where g.nro_orden = c.nro_orden
                              and g.cod_ente = p_cod_ente
                              and nvl(g.nro_archivo, 0) = nvl(p_nro_archivo, 0)),
             cod_ente   = p_cod_ente
       where trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and usu_insercion = v_user
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

      if sql%notfound then
        p_error := 'No encontro registro a actualizar en TMP de facturas';
        return;
      end if;
    exception
      when others then
         p_error := 'Al actualizar TMP de facturas :'||sqlerrm;
         return;
    end;
   --solo si tiene detalles
    if v_tip_comprobante = 'O' then
      -- verifica datos del tmp de facturas
      /*v_tot_factura := 0;
      For reg in c_fac loop
        if reg.nro_orden is null then
           p_error := 'No tiene Nro.de orden en archivo de Facturas';
           return;
        end if;
        if reg.nro_factura is null then
           p_error := 'No tiene Nro.de factura en archivo de Facturas';
           return;
        end if;
        if reg.mto_total is null then
           p_error := 'No tiene Monto de factura en archivo de Facturas';
           return;
        end if;
      end loop;
*/
      -----Controles cruzados entre cabecera y detalle------
      select sum(nvl(mto_total,0))
        into v_todetal
        from ge_pag_pro_facturas_tmp
       where usu_insercion = v_user
         and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and cod_ente = p_cod_ente
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

      select sum(nvl(monto,0))
        into v_tocabec
        from ge_pag_proveedores_tmp
       where usu_insercion = v_user
         and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and cod_ente = p_cod_ente
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

      if v_todetal <> v_tocabec then
         p_error := 'El Total de Cabecera: '||v_tocabec||' no coincide con el Total del Detalle: '||v_todetal||'.';
         return;
      end if;
      v_cantidad := 0;
      select count(*)
        into v_cantidad
        from ge_pag_proveedores_tmp p
       where monto <> (select sum(nvl(mto_total,0))
                        from ge_pag_pro_facturas_tmp f
                        where p.nro_orden = f.nro_orden
                          and nvl(f.nro_archivo, 0) = nvl(p.nro_archivo, 0))
         and cod_ente = p_cod_ente
         and usu_insercion = v_user
         and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
      if nvl(v_cantidad,0) > 0 then
         p_error := 'Los Totales por Orden no coinciden.';
         return;
      end if;
      select count(*)
        into v_cantidad
        from ge_pag_pro_facturas_tmp
       where mto_total < 0
         and usu_insercion = v_user
         and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
         and cod_ente = p_cod_ente
         and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
      if nvl(v_cantidad,0) > 0 then
         p_error := 'Existen Facturas con Importes Negativos.';
         return;
      end if;

      SELECT COUNT(*)
        INTO v_cantidad
        FROM ge_pag_pro_facturas_tmp A
       WHERE EXISTS (SELECT 0 FROM ge_pag_pro_facturas B
                      WHERE A.nro_orden       = B.nro_orden
                        AND A.fec_carga       = B.fec_carga
                        AND A.cod_ente        = B.cod_ente
                        AND A.nro_factura     = B.nro_factura
                        AND A.mto_total       = B.mto_total
                        and A.concepto        = B.concepto);
      IF NVL(v_cantidad,0) > 0 THEN
        p_error := 'Los datos de Detalle ya estan en el Sistema. Verifique';
        return;
      END IF;
    end if;
  end if;

  -- CR: se comenta el commit
 /* if p_error is null then
    commit; --para q inserte en los tmp
  end if;*/

  -- ver si hubo error en los datos del tmp
  select count(*)
    into v_cant
    from ge_pag_proveedores_tmp
   where cod_proceso <> 0
     and usu_insercion = v_user
     and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
     and cod_ente = p_cod_ente
     and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

   if v_cant > 0 then
      p_error := 'Errores en la verificacion de datos.';
   else
      p_error := null;
   end if;

  --procesar si no tiene errores, cargar en las tablas definitivas
  if p_error is null and p_procesar = 'S' then
    --proceso
    PAG_PRV.PR_INS_GE_PAG_PROVEEDORES_DEV(p_cod_ente, nvl(v_fec_insercion,v_fec_actual),p_error, p_nro_archivo);
    if p_error is not null then
      return;
    end if;
    if v_tip_comprobante = 'O' then
      PAG_PRV.PR_INS_GE_PAG_PRO_FACTURAS_DEV(p_cod_ente, nvl(v_fec_insercion,v_fec_actual), p_error, p_nro_archivo);
    else
      --insertar el detalle igual q la cabecera, si es que no tiene detalles
      begin
        insert into ge_pag_pro_facturas
               (nro_orden, fec_carga, nro_factura, mto_total, concepto,  cod_ente )
        select nro_orden, fec_ingreso, nro_factura, monto, concepto, cod_ente
          from ge_pag_proveedores_tmp
         where cod_ente = p_cod_ente
           and usu_insercion = user
           and trunc(fec_insercion) = nvl(v_fec_insercion,v_fec_actual)
           and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);
      exception
        when others then
           p_error := 'Error al actualizar detalles '||sqlerrm;
      end;
    end if;
    if p_error is not null then
      return;
    end if;
  end if;
exception
   when others then
      if sqlcode <= -20000 then
        raise;
      else
        raise_application_error (-20000,'Verif.Datos Pag.Prov. '||sqlerrm);
      end if;
end PR_VER_DAT_TMP_DEV;
--NVB-2232
   /* Insertar en GE_PAG_PROVEEDORES desde el TMP */
PROCEDURE PR_INS_GE_PAG_PROVEEDORES_DEV
 (P_COD_EMPRESA IN NUMBER
 ,P_FECHA IN DATE
 ,P_ERROR OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 )
 IS
  CURSOR ordenes IS
   SELECT nro_orden,
          nro_factura,
          tip_comprobante,
          for_pago,
          nro_cheque,
          nro_cta_credito,
          nro_Cta_debito,
          fec_ingreso,
          fec_pago,
          monto,
          nro_recibo,
          beneficiario,
          concepto,
          estado,
          cod_usu_operador,
          cod_ente,
          cod_moneda,
          tip_carga,
          ref_facturas,
          referencia,
          mon_tot_recibo,
          ret_fac_proveedor,
          des_fac_proveedor,
          ret_facturas,
          des_sucursal,
          nro_archivo,
          ent_bca_beneficiario,
          cod_tip_doc_beneficiario,
          nro_doc_beneficiario,
          ind_valor,
          nro_cta_beneficiario,
          dir_beneficiario,
          tip_factura,
          nro_con_cambio,
          ben_dir_correo,
          nro_ord_archivo,
          cod_swift
     from ge_pag_proveedores_tmp
    where cod_ente             = p_cod_empresa
      and trunc(fec_insercion) = trunc(p_fecha)
      and usu_insercion        = user
      and nvl(tipo,'C')        = 'C'
      and nvl(nro_archivo, 0)  = nvl(p_nro_archivo, 0);
   v_orden ge_pag_proveedores.orden%TYPE;
/* Inserta en la tabla GE_PAG_PROVEEDORES */
BEGIN
   FOR x IN ordenes LOOP
       BEGIN
         SELECT MAX(t.orden)
           INTO v_orden
           FROM ge_pag_proveedores t
          WHERE t.nro_orden = x.nro_orden
            AND t.cod_ente  = x.cod_ente;
         v_orden := nvl( v_orden, 0 ) + 1;
       EXCEPTION
          WHEN no_data_found THEN
              v_orden := 0;
          WHEN OTHERS THEN
              v_orden := 0;
       END;


       INSERT INTO ge_pag_proveedores
                  (nro_orden,
                   nro_factura,
                   tip_comprobante,
                   for_pago,
                   nro_cheque,
                   nro_cta_credito,
                   nro_cta_debito,
                   fec_ingreso,
                   fec_pago,
                   monto,
                   nro_recibo,
                   beneficiario,
                   concepto,
                   estado,
                   cod_usu_operador,
                   cod_ente,
                   cod_moneda,
                   tip_carga,
                   ref_facturas,
                   referencia,
                   mon_tot_recibo,
                   ret_fac_proveedor,
                   des_fac_proveedor,
                   ret_facturas,
                   des_sucursal,
                   nro_archivo,
                   ent_bca_beneficiario,
                   cod_tip_doc_beneficiario,
                   nro_doc_beneficiario,
                   ind_valor,
                   nro_cta_beneficiario,
                   dir_beneficiario,
                   tip_factura,
                   nro_con_cambio,
                   ben_dir_correo,
                   nro_ord_archivo,
                   orden,
                   cod_swift
                    )
         VALUES ( x.nro_orden,
                  x.nro_factura,
                  x.tip_comprobante,
                  x.for_pago,
                  x.nro_cheque,
                  x.nro_cta_credito,
                  x.nro_Cta_debito,
                  x.fec_ingreso,
                  x.fec_pago,
                  x.monto,
                  x.nro_recibo,
                  x.beneficiario,
                  x.concepto,
                  x.estado,
                  x.cod_usu_operador,
                  x.cod_ente,
                  x.cod_moneda,
                  x.tip_carga,
                  x.ref_facturas,
                  x.referencia,
                  x.mon_tot_recibo,
                  x.ret_fac_proveedor,
                  x.des_fac_proveedor,
                  x.ret_facturas,
                  x.des_sucursal,
                  x.nro_archivo,
                  x.ent_bca_beneficiario,
                  x.cod_tip_doc_beneficiario,
                  x.nro_doc_beneficiario,
                  x.ind_valor,
                  x.nro_cta_beneficiario,
                  x.dir_beneficiario,
                  x.tip_factura,
                  x.nro_con_cambio,
                  x.ben_dir_correo,
                  x.nro_ord_archivo,
                  v_orden,
                  x.cod_swift
                  );
         IF SQL%NOTFOUND THEN
            p_error := '-20099, Insertar en ge_pag_proveedores. No existen datos en el tmp';
         ELSE
            p_error := null;
         END IF;
   END LOOP;
EXCEPTION
   WHEN dup_val_on_index THEN
      p_error := '-20199, Registro ya existe en pag_proveedores.';
      --RAISE_APPLICATION_ERROR(-20199,'Registro ya existe en pag_proveedores.');
END PR_INS_GE_PAG_PROVEEDORES_DEV;
--NVB-2232
   /* Insertar en la tabla GE_PAG_PRO_FACTURAS desde el TMP */
PROCEDURE PR_INS_GE_PAG_PRO_FACTURAS_DEV
 (P_COD_EMPRESA IN NUMBER
 ,P_FECHA IN DATE
 ,P_ERROR OUT VARCHAR2
 ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 )
 IS
------------------------------------------------------------
/* Inserta en la tabla GE_PAG_PRO_FACTURAS */
begin
   insert into ge_pag_pro_facturas
              (nro_orden,
               fec_carga,
               nro_factura,
               mto_total,
               concepto,
               cod_ente )
         select nro_orden,
                fec_carga,
                nro_factura,
                mto_total,
                concepto,
                cod_ente
           from ge_pag_pro_facturas_tmp
          where cod_ente = p_cod_empresa
            and trunc(fec_insercion) = trunc(p_fecha)
            and usu_insercion = user
            and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0);

           if sql%notfound then
              p_error :='-20097, Insertar en ge_pag_pro_facturas. No existen datos en el tmp';
              --RAISE_APPLICATION_ERROR(-20097,'Insertar en ge_pag_pro_facturas.No existen datos en el tmp');
           else
              p_error := null;
           end if;
exception
   when dup_val_on_index then
      p_error := '-20199,Registro ya existe en pag_pro_facturas.';
      --RAISE_APPLICATION_ERROR(-20199,'Registro ya existe en pag_pro_facturas.');
end PR_INS_GE_PAG_PRO_FACTURAS_DEV;
-- NVB-2232 Ajustes para cobro de comisiones y opciones de pago
PROCEDURE PR_PRO_PAGO_DEV(p_ente in number default null,
                      p_nro_documento in number default null,
                      p_nro_movimiento  IN bw_movimientos.nro_movimiento%type default 0, /*BWP-311*/
                      p_error out varchar2)  IS
v_cod_modulo         ge_movimientos.cod_modulo%type;
v_cod_modalidad      ge_movimientos.cod_modalidad%type;
v_estado             ge_cuentas.estado%type;
v_sal_disponible     ge_movimientos.monto%type;
v_procesa            VARCHAR2(1) := 'N';
---
v_cod_moneda         ba_monedas.cod_moneda%type;
v_fec_actual         ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(4);
v_fecha              ge_calendarios.fec_actual%type := trunc(sysdate);
v_nro_secuencia      ge_movimientos.nro_secuencia%type :=0;
v_hora               ge_movimientos.hora%type;
v_nro_documento      ge_movimientos.nro_documento%type;
--
v_mod_cta_credito    ge_movimientos.cod_modulo%type;
v_mad_cta_credito    ge_movimientos.cod_modalidad%type;
v_ofi_cta_credito    ge_movimientos.cod_oficina%type;
v_cod_oficina        ge_movimientos.cod_oficina%type;
--
v_cta_Debito         ge_cuentas.nro_cuenta%type;
v_acum_monto         ge_movimientos.monto%type := 0 ;
v_cod_tra_padre      ge_transacciones.cod_transaccion%type;
v_cod_tra_debito     ge_transacciones.cod_transaccion%type;
v_nom_ente           ge_entes.descripcion%type;
v_rub_debito         ge_parametros.parametro%type;
v_tip_comprobante    varchar2(5);
v_pag_fac_atrasada   varchar2(150);
v_ref_texto          varchar2(100);
v_est_modulo         ba_modulos.estado%type; -- OMM 13/12/2010
v_horario            varchar2(1)  := 'D'; -- Día normal -- OMM 13/12/2010
v_es_nocturno        varchar2(1)  := 'N'; -- No es nocturno
v_mensaje_error      VARCHAR2(1000);
v_cod_error          varchar2(3);
v_con_credito        ge_movimientos.concepto%type; -- concepto movimiento crédito
v_con_debito         ge_movimientos.concepto%type; -- concepto movimiento débito
v_can_credito        number;
v_can_debito         number;
v_mod_reg_pago       varchar2(1) default 'N';
v_nro_lote           varchar2(20);

/*UES-1849  -  Para obtener el usuario de la transaccion*/
v_cod_usuario        ge_movimientos.cod_usuario%type;
--Buscamos el cod persona de la empresa
v_cod_empresa        ba_personas.cod_persona%type := fug_obt_per_ente(P_COD_ENTE => p_ente);
--PDSYP-449 
MSG_ERROR_CTACRE     CONSTANT VARCHAR2(500) := 'Error en Cta. de crédito: ';

Cursor c_cabecera is
 Select * from bw_mov_pendientes b
 where to_date(substr(b.dato2,1,10),'DD/MM/YYYY') <= v_fecha -- OMM 21/11/2011 -- x si el pago se cargó el día anterior, igual debe procesar hoy
   and b.estado IN ('C', 'E')
   and b.cod_tip_mensaje = '075'
   and trim(b.dato) = nvl(p_ente, trim(b.dato))
   and b.nro_documento = nvl(p_nro_documento, b.nro_documento)
   and exists (Select 1 from ge_pag_proveedores gp
               where gp.cod_ente = trim(b.dato)
                 and gp.fec_pago = to_date(substr(b.dato2,1,10),'DD/MM/YYYY')
                 and gp.referencia = b.nro_documento
                 and gp.tip_carga = 'H'
                 and gp.estado in ('C', 'R'));

Cursor c_ordenes (p_nro_referencia number, p_cod_ente number) is
SELECT a.*,a.rowid from ge_pag_proveedores a
 where a.estado in('C','R')
   and trunc(a.fec_pago) <= v_fecha -- x si el pago se cargó el día anterior, igual debe procesar hoy
   and a.tip_carga = 'H' -- OMM Solo para Pagos Registrados por el HomeBanking
   and a.referencia = p_nro_referencia
   and a.cod_ente = p_cod_ente
   and a.for_pago != 'I'
   order by a.nro_cta_debito;

/*UES-1849  -  Para obtener el usuario de la transaccion*/   
FUNCTION fu_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type)
    return varchar2 is
    v_nro_sec  number;
    v_can_user number;
    v_nro_user number;
    v_user     ba_usuarios.cod_usuario%type;

  BEGIN
    select count(*)
      into v_can_user
      from ba_cod_referencias
     where dominio     = 'USU_MOV_SERVICIO'
       and abreviatura = p_tip_user;

    v_nro_sec  := fue_obt_sig_secuencia('S_SER_PAYMPVU');
    v_nro_user := mod(v_nro_sec, v_can_user);
    v_user     := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO', v_nro_user, p_tip_user);
    return v_user;
  EXCEPTION
    WHEN OTHERS THEN
     PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S','ERROR_FU_OBT_MOV_USER', 'P_TIP_USER: '|| p_tip_user || ' ERROR EN PAG_PRV.PR_PRO_PAGO_DEV - FU_OBT_MOV_USER ' || SQLERRM),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                           
     p_error := 'ERROR_FU_OBT_MOV_USER';
     RETURN NULL;
     
  END;
 /*UES-1849  -  Para obtener la hora, según el usuario*/
 FUNCTION fu_obt_hora(p_cod_usuario varchar2) return varchar2 is
    v_hora        ge_movimientos.hora%type;
    v_nro_sec     number;
    v_nro_hor     number;
    v_ind_usuario number;

  BEGIN
    
    if instr(p_cod_usuario, '_', 1) = 0 then
      v_ind_usuario := 0;
    else
      --El substr tiene como valor 2 ya que el usuario puede tener más de dos caracteres _15  _11 _10
      v_ind_usuario := substr(p_cod_usuario, instr(p_cod_usuario, '_', 1) + 1, 2);
    end if;

    if v_ind_usuario > 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_movpaympvu' /*||'_'*/|| v_ind_usuario);
    elsif v_ind_usuario = 0 then
      v_nro_sec := fue_obt_sig_secuencia('S_HOR_MOVPAYMPVU');
    end if;

    v_nro_hor := mod(v_nro_sec, 86400);

    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

    return v_hora;
  EXCEPTION
    WHEN OTHERS THEN
      PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S','ERROR_FU_OBT_HORA', 'P_COD_USUARIO: '|| p_cod_usuario ||' ERROR EN PAG_PRV.PR_PRO_PAGO_DEV - FU_OBT_HORA ' || SQLERRM),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
      p_error := 'ERR_FU_OBT_HORA';
      
  END;
BEGIN
  v_hora      := to_char( sysdate, 'HH24:MI:SS' );
  --Para la registración anterior, misma hora
  v_nro_secuencia := 0;  --OMM 09/09/2016 DYDMR-4822. Se ajusta para generar correctamente el movimiento
  v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(4);
  If v_est_modulo = 2 then
    v_horario := 'D' ; -- N=Cerrado, D=Abierto
    v_es_nocturno := 'N';
  else
    v_horario := 'N' ; -- N=Cerrado, D=Abierto
    v_es_nocturno := 'S' ;
  end if;
  
  pag_cta.g_horario := v_horario;
    select nvl(max(a.nro_lote),0)
         into v_nro_lote
           from ge_pag_proveedores a
             where a.fec_pago= pag_cal.fu_obt_fec_actual(1)
               and a.cod_ente= p_ente;

--*
  For cab in c_cabecera loop
    p_error := '00' ;
    v_cod_error:= '00' ;
    v_can_credito := 0;
    v_can_debito  := 0;
    v_acum_monto := 0;
    v_mensaje_error := null ;

    v_mod_reg_pago := fug_obt_parentes(cab.dato,'MOD_REG_PAG_PRV'); /* N=Normal, P=Por operación*/

    if v_mod_reg_pago is null then
      v_mod_reg_pago := 'N';
    end if;
    /* UES-1849
       Si el modo de registro es normal, se procede
       a buscar el usuario y la hora
    */
    IF v_mod_reg_pago = 'N' THEN
      v_cod_usuario := fu_obt_mov_user('PAYMPVU');
      v_hora := fu_obt_hora(v_cod_usuario);
    END IF;

    pag_prv.PR_OBT_DAT_PROVEEDOR (cab.dato, v_nom_ente, v_tip_comprobante, v_cod_tra_padre,
                   v_cta_Debito, v_pag_fac_atrasada, v_ref_texto, v_cod_tra_debito ,v_rub_debito);

    if cab.tip_pago = 'P' then -- Opción de pago Pago a proveedores
      v_con_credito := substr('Crédito por Pago a Proveedores: Empresa '||v_nom_ente, 1, 100);
      v_con_debito  := substr('Débito por Pago a Proveedores: Empresa '||v_nom_ente, 1, 100);
    else -- Opción de pago Crédito en Cuenta
      v_cod_tra_padre := fug_obt_parentes(cab.dato, 'COD_TRA_PAD_PRV_CREDITO');
      v_con_credito := substr('Crédito en Cuenta: Empresa '||v_nom_ente, 1, 100);
      v_con_debito  := substr('Débito por Transferencia: Empresa '||v_nom_ente, 1, 100);
    end if;

    BEGIN
      SELECT gc.cod_oficina, gc.cod_modulo, gc.cod_modalidad, gc.cod_moneda
        INTO v_cod_oficina, v_cod_modulo, v_cod_modalidad, v_cod_moneda
        FROM ge_cuentas gc
       WHERE nro_cuenta = cab.nro_cuenta;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN   
        v_cod_error := '01';
        v_mensaje_error := 'Cta. de Débito inexistente para el Ente '||cab.dato ;
       p_error:=v_cod_error||'-'||v_mensaje_error;
       PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
       
      WHEN TOO_MANY_ROWS THEN
        v_cod_error := '02';
        v_mensaje_error := 'Cta. de Débito '||cab.nro_cuenta||' duplicado en ge_cta_clientes o Maestro' ;
        p_error:=v_cod_error||'-'||v_mensaje_error;
        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
    END;
    if p_error = '00' then
      For reg in c_ordenes(cab.nro_documento, cab.dato) loop
        v_nro_documento:=null;
        --- busco los datos de la cta crédito, sólo si tuviera
        if reg.nro_cta_credito is not null then
          begin
            select cod_modulo, cod_modalidad, cod_oficina
              into v_mod_cta_credito, v_mad_cta_credito, v_ofi_cta_credito
              from ge_cuentas
             where nro_cuenta = reg.nro_cta_credito;
          exception
            when no_data_found then
              v_cod_error := '03';
              v_mensaje_error := 'Cta. de crédito inexistente Nro '||reg.nro_cta_credito ;
               p_error:=v_cod_error||'-'||v_mensaje_error;
               PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null); 
              --PDSYP-449             
              p_error := MSG_ERROR_CTACRE ||reg.nro_cta_credito ;
            when others then
              v_cod_error := '04';
              v_mensaje_error := 'Eror Critico con Cta. de crédito. '||sqlerrm ;
              p_error:=v_cod_error||'-'||v_mensaje_error;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
              --PDSYP-449
              p_error := MSG_ERROR_CTACRE ||reg.nro_cta_credito ;
            end;
        end if;

        -- OMM 09/09/2016 DYDMR-4822. Se ajusta para generar correctamente el movimiento
        if v_nro_secuencia > 990 then
              v_nro_secuencia := -999;
        elsif v_nro_secuencia < 0 and v_nro_secuencia > -10 then
              v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
              v_nro_secuencia := 0 ;
        end if;

        --Se guarda Hora y Nro.Documento Acorde a Tipo de Registración
        if v_mod_reg_pago ='N' then
          v_nro_documento:=cab.nro_documento;
        else
          --Por Operación
          v_cod_usuario := fu_obt_mov_user('PAYMPVU');
          v_hora := fu_obt_hora(v_cod_usuario);
           --- inserto Nro.Doc.Diferente
           SELECT s_nro_documento.nextval
              INTO v_nro_documento
               FROM dual;
           v_nro_secuencia := 0 ;  -- OMM feb/2017 DYDMR-6125
        end if;

        --CRÉDITO EN CUENTA
        if reg.for_pago = 'C' and p_error = '00' then
          /*UES-1849 - Seteamos variables*/
          pag_Cta.PR_SET_VARIABLES(p_cod_usuario    => v_cod_usuario,
                                   p_fec_valor      => v_fec_actual,
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_nro_secuencia,
                                   p_est_cuenta     => NULL,
                                   p_cod_ofi_origen => v_cod_oficina,
                                   p_cod_mod_padre  => v_cod_modulo,
                                   p_cod_mad_padre  => v_cod_modalidad); 
          /* acreditar la cuenta de crédito */
          pag_cta.pr_act_operacion(reg.nro_cta_credito,
                                   v_hora,            --HORA
                                   'C',
                                   reg.cod_moneda,    --Moneda de la Operación
                                   reg.monto,
                                   v_cod_tra_padre,   --COD_TRA_PADRE
                                   7602,               -- COD_TRA_HIJO
                                   to_number(p_nro_movimiento||'075'),--BWP-311 v_nro_documento,   --cab.nro_documento, --:PROV.NRO_RECIBO,
                                   NULL,              --COTIZACION
                                   v_cod_oficina,     --cod_ofi_origen
                                   v_cod_modulo,      --cod_mod_padre
                                   v_cod_modalidad,   --cod_mad_padre
                                   null,              --cod_tasa
                                   null,              --val_tasa
                                   v_con_credito,     --descripción
                                   'S',               --emi_aviso
                                   v_nro_secuencia,
                                   v_fec_actual);

          if pag_cta.fu_obt_cod_error() <> 0 then
            v_cod_error := '05';
            v_mensaje_error := 'Error con Cta Cred '|| reg.nro_cta_credito || '-'||pag_cta.fu_obt_msj_error;
            p_error:=v_cod_error||'-'||v_mensaje_error;
            PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
            --PDSYP-449
            p_error := MSG_ERROR_CTACRE ||reg.nro_cta_credito ;
          else
            v_acum_monto := nvl(v_Acum_monto,0) + reg.monto;
            v_can_credito := v_can_credito + 1;
            --actualizar movimientos con el nro_orden
            if v_horario = 'D' then
              update ge_movimientos
                 set nro_documento2 = reg.nro_orden,
                     nro_documento3 = reg.cod_ente
               where fecha = v_fec_actual
                 and cod_usuario = v_cod_usuario --por el usuario UES-1849
                 and hora = v_hora
                 and reversado ='N'
                 and nro_secuencia = v_nro_secuencia
                 and cod_tra_padre = v_cod_tra_padre;
            else
              update ge_movimientos_noc
                 set nro_documento2 = reg.nro_orden,
                     nro_documento3 = reg.cod_ente
               where fecha = v_fec_actual
                 and cod_usuario = v_cod_usuario --por el usuario UES-1849
                 and hora = v_hora
                 and reversado ='N'
                 and nro_secuencia = v_nro_secuencia
                 and cod_tra_padre = v_cod_tra_padre;
            end if;
          end if;
        End if;
        ---Si no hubo errores actualiza tablas
        If p_error = '00' then
          UPDATE ge_pag_proveedores
             SET nro_recibo      = null,
                 estado          = 'N',
                 fec_pago        = v_fecha,
                 hora            = v_hora,
                 nro_documento   = v_nro_documento,
                 nro_pago        = to_char(pag_cal.fu_obt_fec_actual(1),'yymmdd')||replace(v_hora,':','')||v_nro_secuencia,
                 nro_lote        = to_number(v_nro_lote)+1
           WHERE rowid= reg.rowid;
              /*cod_ente        = reg.cod_ente
             AND trunc(fec_pago) <= v_fec_actual -- x si el pago se cargó el día anterior, igual debe procesar hoy
             AND nro_orden       = reg.nro_orden
             AND nvl(nro_factura,'0') = nvl(reg.nro_factura,'0') --CC-Mejoras en Pago a Proveedores/PCCMEJPP-93
             AND usu_insercion   = reg.usu_insercion
             AND estado in ('C','R');*/

          IF SQL%NOTFOUND THEN
            v_cod_error := '06';
            v_mensaje_error := 'Error al actualizar GE_PAG_PROVEEDORES. Ente-Orden: '||reg.cod_ente||'-'||reg.nro_orden;
            p_error:=v_cod_error||'-'||v_mensaje_error;
            PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
          END IF;
        End if;
        --------------------------------------------------------------------
        if v_mod_reg_pago = 'P' then -- Modalidad de Pago D/C por Operación.
          if v_cod_modalidad in (31,41) and p_error = '00' then
            pag_cta.pr_ver_operacion(cab.nro_cuenta,
                                     v_cod_tra_padre,
                                     v_cod_modulo,
                                     v_cod_modalidad,
                                     'D',
                                     v_cod_moneda,
                                     reg.monto,
                                     v_cod_oficina,
                                     v_cod_modulo,
                                     v_cod_modalidad,
                                     v_estado,
                                     v_sal_disponible,
                                     v_procesa,
                                     7503);
            if v_procesa = 'N' then
              v_cod_error := '07';
              v_mensaje_error := 'Error con Cta Debito '||cab.nro_cuenta||'-'||pag_cta.fu_obt_msj_error;
              p_error:=v_cod_error||'-'||v_mensaje_error;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
            else
              v_can_debito := v_can_debito + 1;

              if p_error = '00' then
                /* establecemos el código del ente en nro_documento3 para sumarizar
                   los límites de operación por ente en pago a proveedores */
                pag_cta.pr_set_nro_documento3(cab.dato);
                /*UES-1849 - Seteamos variables*/
                pag_Cta.PR_SET_VARIABLES(p_cod_usuario    => v_cod_usuario,
                                   p_fec_valor      => v_fec_actual,
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_nro_secuencia,
                                   p_est_cuenta     => NULL,
                                   p_cod_ofi_origen => v_cod_oficina,
                                   p_cod_mod_padre  => v_cod_modulo,
                                   p_cod_mad_padre  => v_cod_modalidad);
                /* debitar a la cuenta de débito */
                pag_cta.pr_act_operacion(cab.nro_cuenta,
                                         v_hora,--HORA
                                         'D',
                                         v_cod_moneda,
                                         reg.monto,
                                         v_cod_tra_padre,--COD_TRA_PADRE
                                         nvl(v_cod_tra_debito,503),    -- COD_TRA_HIJO
                                         to_number(p_nro_movimiento||'075'),--BWP-311 v_nro_documento,  --cab.nro_documento, --:PROV.NRO_RECIBO,
                                         null,                     --COTIZACION
                                         v_cod_oficina,    --cod_ofi_origen
                                         v_cod_modulo,    --cod_mod_padre
                                         v_cod_modalidad, --cod_mad_padre
                                         null, --cod_tasa
                                         null, --val_tasa
                                         v_con_debito,
                                         'S', --emi_aviso
                                         v_nro_secuencia,
                                         v_fec_actual);

                if pag_cta.fu_obt_cod_error() <> 0 then
                  v_cod_error := '09';
                  v_mensaje_error := 'Error al Tratar de Procesar Debito. '||pag_cta.fu_obt_msj_error;
                  p_error:=v_cod_error||'-'||v_mensaje_error;
                  PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                end if;
              end if;

              v_acum_monto := 0 ;
            End if;
          End if ; -- end if v_cod_modalidad in (31,41) débito
        end if;
      End Loop; -- For reg in c_ordenes
   IF v_mod_reg_pago != 'P' THEN -- Modalidad de Pago D/C por Operación.
      if v_cod_modalidad in (31,41) and p_error = '00' then
        pag_cta.pr_ver_operacion(cab.nro_cuenta,
                                 v_cod_tra_padre,
                                 v_cod_modulo,
                                 v_cod_modalidad,
                                 'D',
                                 v_cod_moneda,
                                 v_acum_monto, --cab.monto,  -- DYDMR-3116 -- CN: 03/2016 -- Debe verificar solo el monto pendiente no el total del lote.
                                 v_cod_oficina,
                                 v_cod_modulo,
                                 v_cod_modalidad,
                                 v_estado,
                                 v_sal_disponible,
                                 v_procesa,
                                 503);
        if v_procesa = 'N' then
          v_cod_error := '10';
          v_mensaje_error := 'Error con Cta Debito '||cab.nro_cuenta||'-'||pag_cta.fu_obt_msj_error;
          p_error:=v_cod_error||'-'||v_mensaje_error;
          PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
        else
          -- Verifico si el detallado es igual al total para debitar
         /* if v_acum_monto <> cab.monto then
            p_error := '11';
            v_mensaje_error := 'Monto Detalle no coincide con Total. Ente: '||cab.dato ;
          end if ;*/

          if p_error = '00' and v_acum_monto > 0 then
            /* establecemos el código del ente en nro_documento3 para sumarizar
               los límites de operación por ente en pago a proveedores */
            pag_cta.pr_set_nro_documento3(cab.dato);
            /*UES-1849 - Seteamos variables*/
            pag_Cta.PR_SET_VARIABLES(p_cod_usuario    => v_cod_usuario,
                                   p_fec_valor      => v_fec_actual,
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_nro_secuencia,
                                   p_est_cuenta     => NULL,
                                   p_cod_ofi_origen => v_cod_oficina,
                                   p_cod_mod_padre  => v_cod_modulo,
                                   p_cod_mad_padre  => v_cod_modalidad); 
            /* debitar a la cuenta de débito */
            pag_cta.pr_act_operacion(cab.nro_cuenta,
                                     v_hora,--HORA
                                     'D',
                                     v_cod_moneda,
                                     v_acum_monto,
                                     v_cod_tra_padre,--COD_TRA_PADRE
                                     nvl(v_cod_tra_debito,503),    -- COD_TRA_HIJO
                                     to_number(p_nro_movimiento||'075'),--BWP-311 cab.nro_documento, --:PROV.NRO_RECIBO,
                                     null,                     --COTIZACION
                                     v_cod_oficina,    --cod_ofi_origen
                                     v_cod_modulo,    --cod_mod_padre
                                     v_cod_modalidad, --cod_mad_padre
                                     null, --cod_tasa
                                     null, --val_tasa
                                     v_con_debito,
                                     'S', --emi_aviso
                                     v_nro_secuencia,
                                     v_fec_actual);

            if pag_cta.fu_obt_cod_error() <> 0 then
              v_cod_error := '12';
              v_mensaje_error := 'Error al Tratar de Procesar Debito. '||pag_cta.fu_obt_msj_error;
              p_error:=v_cod_error||'-'||v_mensaje_error;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
            end if;
          end if;
          -- se cobran las comisiones correspondientes
          if p_error = '00' and v_acum_monto > 0 then
            pr_cob_comision('COD_TRA_COM_INDIVIDUAL',
                            'Comisión por Crédito Individual de Pago a Proveedores',
                            cab.dato,
                            v_cod_tra_padre,
                            cab.nro_cuenta,
                            v_cod_modulo,
                            v_cod_modalidad,
                            v_cod_moneda,
                            v_acum_monto,
                            v_cod_oficina,
                            v_can_credito,
                            cab.nro_documento,
                            v_fec_actual,
                            v_hora,
                            v_nro_secuencia,
                            p_error,
                            v_mensaje_error);
          end if;

          if p_error = '00' and v_acum_monto > 0 then
            pr_cob_comision('COD_TRA_COM_SERVICIO',
                            'Comisión por Servicio de Pago a Proveedores',
                            cab.dato,
                            v_cod_tra_padre,
                            cab.nro_cuenta,
                            v_cod_modulo,
                            v_cod_modalidad,
                            v_cod_moneda,
                            v_acum_monto,
                            v_cod_oficina,
                            1,
                            cab.nro_documento,
                            v_fec_actual,
                            v_hora,
                            v_nro_secuencia,
                            p_error,
                            v_mensaje_error);
          end if;

        End if;
      End if ; -- end if v_cod_modalidad in (31,41)
    ELSE
              -- se cobran las comisiones Por la Modalidad D/C Por Operación.
              if p_error = '00' and v_acum_monto > 0 then
                pr_cob_comision('COD_TRA_COM_INDIVIDUAL',
                                'Comisión por Crédito Individual de Pago a Proveedores',
                                cab.dato,
                                v_cod_tra_padre,
                                cab.nro_cuenta,
                                v_cod_modulo,
                                v_cod_modalidad,
                                v_cod_moneda,
                                v_acum_monto,
                                v_cod_oficina,
                                v_can_credito,
                                cab.nro_documento,
                                v_fec_actual,
                                v_hora,
                                v_nro_secuencia,
                                p_error,
                                v_mensaje_error);
              end if;

              if p_error = '00' and v_acum_monto > 0 then
                pr_cob_comision('COD_TRA_COM_SERVICIO',
                                'Comisión por Servicio de Pago a Proveedores',
                                cab.dato,
                                v_cod_tra_padre,
                                cab.nro_cuenta,
                                v_cod_modulo,
                                v_cod_modalidad,
                                v_cod_moneda,
                                v_acum_monto,
                                v_cod_oficina,
                                v_can_debito,
                                cab.nro_documento,
                                v_fec_actual,
                                v_hora,
                                v_nro_secuencia,
                                p_error,
                                v_mensaje_error);
              end if;
              v_acum_monto := 0 ;
    END IF;
    end if ; -- end if (p_error = '00')
    -- Veifica si terminó bien hace commit, sino hace rollback
    if p_error <> '00' or v_cod_error <> '00' then
      /*commit ;
    else*/
      it_mail.mail( fug_obt_dir_correo,
                    fug_obt_pardinamico('SUE_DIR_CORREO'),
                    'Error al Tratar de Procesar Pago a Proveedores',
                    'ERROR EN PROCESO DE CRÉDITO Y DÉBITO PARA PAGO A PROVEEDORES'|| chr(10) ||chr(10) ||
                    'Codigo  : ' || cab.dato|| chr(10) ||
                    'Empresa : ' || v_nom_ente|| chr(10) ||
                    'Codigo de Error: ' || p_error || chr(10) ||
                    'Error Registrado: ' || v_mensaje_error || chr(10) ||chr(10) ||
                    'Atentamente. '
                    );
      --rollback;
    end if ;
    -- limpiamos la variable global
    pag_cta.pr_set_nro_documento3(NULL);
  End Loop;

EXCEPTION
  when others then
    v_cod_error := '99';
    p_error:=v_cod_error||'-'||sqlerrm;
    -- limpiamos la variable global
    pag_cta.pr_set_nro_documento3(NULL);
    lp_reg_operacion('pag_prv.pr_pro_pago- ente:'||p_ente||', nro_doc:'||p_nro_documento, SQLERRM);
    PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAGO_DEV',
                           p_det_error    => fu_generarBitacora('S',v_cod_error, p_error ),
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
END PR_PRO_PAGO_DEV;
/* Proceso de pago a proveedores a través de SNP */
PROCEDURE PR_PRO_PAG_SNP_DEV(p_cod_ente in ge_entes.cod_ente%type,
                          p_usuario  in ba_usuarios.cod_usuario%type,
                          p_cod_error out varchar2,
                          p_error    out varchar2,
                          p_fec_pago date default null,
                          p_nro_archivo ge_pag_proveedores.nro_archivo%type default null,
                          p_nro_documento  IN bw_movimientos.nro_documento%type default 0 /*BWP-526*/) IS

  rg_ge_snp_trans       pas_snp.rg_msj;
  v_cod_tip_ope_av      ge_snp_transferencias.cod_tip_operacion%type;
  v_cod_sub_tip_ope_av  ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_cod_tip_ope_bv      ge_snp_transferencias.cod_tip_operacion%type;
  v_cod_sub_tip_ope_bv  ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_cod_sub_tip_ope_bcp ge_snp_transferencias.cod_sub_tip_operacion%type := nvl(fug_obt_pardinamico('SNP_SUB_TIP_OPE_TRA_BCP'),'005');  -- DDSI-62
  v_cod_mon_cta_debito  ge_cuentas.cod_moneda%type;
  v_cant                number;
  v_nro_con_cambio      number(18);
  v_can_con_cambio      number(9);
  v_est_periodo         varchar2(1);
  v_nro_lote            varchar2(20);
  v_concepto            varchar2(1000);
  v_lon_nro_referencia  number(10);
  v_lon_concepto        number(10);
  v_lon_nro_factura     number(10);
  v_lon_cadena          number(10);
  v_disponible          number(10);
  v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_spi_hab_pp          VARCHAR2(1) := fug_obt_pardinamico('SPI_HAB_PP');  
  v_cod_swift           gv_snp_participantes.cod_swift%type;
  v_fec_sugerida        date;
  v_fec_operacion       date:=p_fec_pago;
  v_mes_sugerida        number(2);
  v_mes_fec_cal         number(2);
  v_fec_actual          date := pag_cal.fu_obt_fec_actual(9);
  v_fec_pago            date := trunc(SYSDATE);
  v_estado              ge_snp_transferencias.estado%type;
  v_patrocinador        varchar2(1) := 'N';
  v_cod_swift_sub       ge_snp_transferencias.cod_swi_suc_beneficiario%type;
  v_cta_sub             ge_snp_transferencias.nro_cta_suc_pte_beneficiario%type;
  v_cam_fecha   BOOLEAN := FALSE;
  v_cta_pte_solicitante varchar2(20); -- Nro de Cuenta Interbancaria
  v_cod_mon_debito      ge_cuentas.cod_moneda%type;   -- moneda de la cuenta
  v_cod_respuesta number(10);
  v_desc_respuesta varchar2(4000);
  v_ind_habil varchar2(1):='S';
  v_concepto_tra            ge_movimientos.concepto%type;
  v_existe varchar(1);
  
  --Buscamos el cod persona de la empresa
  v_cod_empresa        ba_personas.cod_persona%type := fug_obt_per_ente(P_COD_ENTE => p_cod_ente);
  
  cursor c_pagos is
    select a.*,a.rowid
      from ge_pag_proveedores a
     where a.cod_ente = p_cod_ente
       and a.estado in('C','R')
       and a.usu_insercion = p_usuario
       and a.for_pago = 'I'
       and (p_fec_pago is null or trunc(a.fec_pago) = trunc(p_fec_pago))
       and (p_nro_archivo is null or a.nro_archivo = p_nro_archivo)
     order by a.nro_cta_debito;
   reg c_pagos%rowtype;

  cursor c_deb is
    select b.* 
      from ge_pag_proveedores a, ge_snp_transferencias b
     where a.nro_referencia = b.nro_referencia
       and a.cod_ente = p_cod_ente
       and a.estado = 'N'
       and a.usu_insercion = p_usuario
       and a.for_pago = 'I'
       and (p_fec_pago is null or trunc(a.fec_pago) = trunc(p_fec_pago))
       and (p_nro_archivo is null or a.nro_archivo = p_nro_archivo)
       and b.situacion = 'P'
       and b.estado IN ( 'S','A')
     order by a.nro_cta_debito;
BEGIN

   if fug_obt_parentes(p_cod_ente, 'SNP_HAB_PROVEEDORES') != 'S' then
      p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
      p_error := '75-ENTIDAD NO HABILITADA PARA PAGOS INTERBANCARIA';
      PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
      return;
   end if;
    prg_cre_savepoint('sipap');
   /*Datos en común*/
   BEGIN
   --hallo tipo y subtipo de op. para el ente
   v_cod_tip_ope_av     := fug_obt_val_delimitador(fug_obt_parentes(p_cod_ente, 'SNP_TIP_AV_PROVEEDORES'), ',', 1);
   v_cod_sub_tip_ope_av := fug_obt_val_delimitador(fug_obt_parentes(p_cod_ente, 'SNP_TIP_AV_PROVEEDORES'), ',', 2);
   v_cod_tip_ope_bv     := fug_obt_val_delimitador(fug_obt_parentes(p_cod_ente, 'SNP_TIP_BV_PROVEEDORES'), ',', 1);
   v_cod_sub_tip_ope_bv := fug_obt_val_delimitador(fug_obt_parentes(p_cod_ente, 'SNP_TIP_BV_PROVEEDORES'), ',', 2);
   rg_ge_snp_trans.tip_cargo         := fug_obt_parentes(p_cod_ente, 'SNP_TIP_CAR_PROVEEDORES');
   EXCEPTION
     WHEN OTHERS THEN
       p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
       p_error := 'ERROR AL OBTENER PARAMETROS DE ENTE: '||sqlerrm;
       PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
       return;
   END;

   rg_ge_snp_trans.cod_modulo        := pas_snp.fu_obt_cod_mod_padre;
   rg_ge_snp_trans.cod_modalidad     := pas_snp.fu_obt_cod_mad_padre;
   rg_ge_snp_trans.tip_mensaje       := 'CRED';
   rg_ge_snp_trans.origen            := 'I';
   rg_ge_snp_trans.plataforma        := 'X';
   rg_ge_snp_trans.indemnizado       := 'N';

   -- Hallo Datos del Ente solicitante
   begin
       select a.cod_persona,
              a.descripcion,
              b.cod_tip_documento,
              b.nro_documento
         into rg_ge_snp_trans.cod_per_solicitante,
              rg_ge_snp_trans.nom_solicitante,
              rg_ge_snp_trans.cod_tip_doc_solicitante,
              rg_ge_snp_trans.nro_doc_solicitante
         from ge_entes a,
              ba_personas b
        where cod_ente = p_cod_ente
          and a.cod_persona = b.cod_persona;
   exception
      when others then
         p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
         p_error := 'ERROR AL HALLAR DATOS DEL ENTE SOLICITANTE: '||sqlerrm;
         PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
         return;
   end;
   
   rg_ge_snp_trans.cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
    select nvl(max(a.nro_lote),0)
         into v_nro_lote
           from ge_pag_proveedores a
             where a.fec_pago= pag_cal.fu_obt_fec_actual(1)
               and a.cod_ente=p_cod_ente;
    open c_pagos;
    loop 
      fetch c_pagos
      into reg;
      exit when c_pagos%notfound;
   --for reg in c_pagos loop
      --Se limpian variables para volver a cargar
      rg_ge_snp_trans.nro_referencia := null;
      rg_ge_snp_trans.fecha := null;
      rg_ge_snp_trans.fec_valor := null;
      rg_ge_snp_trans.hora  := null;
      rg_ge_snp_trans.situacion := null;
      rg_ge_snp_trans.estado := null;
      rg_ge_snp_trans.nro_cta_solicitante:=null;
      v_cod_mon_cta_debito:=null;
      rg_ge_snp_trans.cod_oficina:=null;
      p_error := null;
      rg_ge_snp_trans.ind_valor :=null;
      rg_ge_snp_trans.cod_msj_swift := null;
      rg_ge_snp_trans.cod_tip_operacion := null;
      rg_ge_snp_trans.cod_sub_tip_operacion := null;
      rg_ge_snp_trans.fec_ingreso := null;
      rg_ge_snp_trans.cod_moneda := null;
      rg_ge_snp_trans.monto := null;
      rg_ge_snp_trans.nro_cta_pte_solicitante :=null;
      rg_ge_snp_trans.cod_tip_doc_beneficiario := null;
      rg_ge_snp_trans.nro_doc_beneficiario :=null;
      rg_ge_snp_trans.cod_per_beneficiario := null;
      rg_ge_snp_trans.nom_beneficiario := null;
      rg_ge_snp_trans.dir_beneficiario := null;
      rg_ge_snp_trans.nro_cta_beneficiario := null;
      rg_ge_snp_trans.cod_swi_pte_beneficiario:=null;
      rg_ge_snp_trans.nro_cta_pte_beneficiario:=null;
      rg_ge_snp_trans.concepto:=null;
      rg_ge_snp_trans.prioridad:=null;
      rg_ge_snp_trans.msj_swift :=null;
      --rg_ge_snp_trans.cod_tra_padre := null;
      pas_snp.g_msj_error:=null;
      rg_ge_snp_trans.nro_referencia := pas_snp.fu_obt_sig_nro_referencia;
      rg_ge_snp_trans.cod_usuario := null;
      rg_ge_snp_trans.situacion := 'P';
      rg_ge_snp_trans.estado  := 'S' ; -- Solicitado
      rg_ge_snp_trans.ref_oid:='PPV';--código propio para el tipo de pago a proveedores
      v_fec_operacion       :=p_fec_pago;
      v_est_periodo:= null;
      --Obtengo datos de la cta de débito una sola vez
      if nvl(rg_ge_snp_trans.nro_cta_solicitante, 'X') != reg.nro_cta_debito then
         rg_ge_snp_trans.nro_cta_solicitante := reg.nro_cta_debito;
         pag_cta.pr_obt_cuenta(rg_ge_snp_trans.nro_cta_solicitante);
         v_cod_mon_cta_debito := pag_cta.g_ctas.cod_moneda;
         rg_ge_snp_trans.cod_oficina := pag_cta.g_ctas.cod_oficina;
         if pag_cta.fu_obt_cod_error <> 0 then
           p_error := pag_cta.fu_obt_msj_error;
           PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',pag_cta.fu_obt_cod_error, pag_cta.fu_obt_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
           return;
         end if;
      end if;
      rg_ge_snp_trans.ind_valor := 'S';
       --Se controla el swift de la entidad de destino
      begin
        select b.cod_swift
          into v_cod_swift
          from gv_snp_participantes b
         where b.cod_swift= reg.cod_swift 
           and b.cod_persona != fug_obt_per_entidad;
      exception
        when no_data_found then
           --controla subparticipantes
           begin 
               --Controla patrocinadores
                select p.cod_swift_sub
                  into v_cod_swift
                  from ge_snp_patrocinador_det p
                 where p.cod_swift_sub = reg.cod_swift
                   and estado = 'S';
                   exception 
                      when no_data_found then
                        p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                        p_error := 'ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.ent_bca_beneficiario||': '||sqlerrm;
                        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                        return;
                      when others  then
                        p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                        p_error := 'ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.ent_bca_beneficiario||': '||sqlerrm;
                        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
             return;
                 end;
          when others then
             p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
             p_error := 'ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.ent_bca_beneficiario||': '||sqlerrm;
             PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
             return;
      end;
      --Se verifica Patrocinadores
        
         begin
          select 'S', cod_swift_sub, cta_interna_sub,cod_swift_padre
            into v_patrocinador, v_cod_swift_sub, v_cta_sub,v_cod_swift
            from ge_snp_patrocinador_det
           where cod_swift_sub = v_cod_swift
             and estado = 'S';
          exception
            when no_data_found then
              v_patrocinador := 'N';
              v_cod_swift_sub:=null;
              v_cta_sub:=null;
         end;
   
     --Asignacion Inicial de tipo y sub tipo operacion
     rg_ge_snp_trans.cod_msj_swift := 103;
     rg_ge_snp_trans.cod_tip_operacion := '001';
     rg_ge_snp_trans.cod_sub_tip_operacion := '002';
     rg_ge_snp_trans.cod_moneda := reg.cod_moneda;
     rg_ge_snp_trans.monto := reg.monto;
     -- Control de horario snp, para validar tipo de mensaje a enviar 
     if pas_snp.fu_obt_est_horario( rg_ge_snp_trans.cod_msj_swift,
                   rg_ge_snp_trans.cod_tip_operacion,
                    rg_ge_snp_trans.cod_sub_tip_operacion
                 ) = 'A' then --Si el horario está VIGENTE en BCP
       rg_ge_snp_trans.cod_msj_swift := 103;
       rg_ge_snp_trans.cod_tip_operacion := '001';
       rg_ge_snp_trans.cod_sub_tip_operacion := '002';
     elsif pas_snp.fu_obt_est_horario( rg_ge_snp_trans.cod_msj_swift,
                                       rg_ge_snp_trans.cod_tip_operacion,
                                       rg_ge_snp_trans.cod_sub_tip_operacion ) <> 'A' --Si el horario está CERRADO en BCP then
                    and fus_obt_cod_msj_homebanking(pag_cal.fu_obt_fec_actual(1)) = 'MT103' then -- Horario corresponde a MT103
                    rg_ge_snp_trans.cod_msj_swift := 103;
                    rg_ge_snp_trans.cod_tip_operacion := '001';
                    rg_ge_snp_trans.cod_sub_tip_operacion := '002';
                     rg_ge_snp_trans.ind_valor := 'S';
      elsif pas_snp.fu_obt_est_horario( rg_ge_snp_trans.cod_msj_swift,
                     rg_ge_snp_trans.cod_tip_operacion,
                     rg_ge_snp_trans.cod_sub_tip_operacion
                   ) <> 'A' --Si el horario está CERRADO en BCP then
            and fus_obt_cod_msj_homebanking(pag_cal.fu_obt_fec_actual(1)) = 'MT102' then -- Horario corresponde a MT102
                     rg_ge_snp_trans.cod_msj_swift         := 102;
                     rg_ge_snp_trans.cod_tip_operacion     := '011';
                     rg_ge_snp_trans.cod_sub_tip_operacion := '001';
                     rg_ge_snp_trans.ind_valor := 'N';
     end if;
    if nvl(v_patrocinador,'N')='S' THEN ---si es sub-participante debe enviar mt103
          rg_ge_snp_trans.cod_msj_swift:=103;
          rg_ge_snp_trans.cod_tip_operacion            := '001';
          rg_ge_snp_trans.cod_sub_tip_operacion        := '004';
          rg_ge_snp_trans.tip_cargo                    := 'OUR';
          rg_ge_snp_trans.nro_ref_externa:=null;
          rg_ge_snp_trans.ind_valor := 'S';
        /*  rg_ge_snp_trans.cod_swi_suc_beneficiario     := v_cod_swift_sub;
          rg_ge_snp_trans.nro_cta_suc_pte_beneficiario := v_cta_sub;*/
     end if;
    if p_fec_pago !=pag_cal.fu_obt_fec_habil(trunc(sysdate),1,rg_ge_snp_trans.cod_oficina) then
      v_ind_habil:='N';
    end if;
    if it.pas_spi.fu_obt_tra_spi(reg.cod_moneda,reg.monto,v_patrocinador, v_cod_swift) ='S' and v_spi_hab_pp='S' then                 
                    
                     rg_ge_snp_trans.cod_msj_swift := fug_obt_pardinamico( 'COD_SPI_PCD' );
                     v_fec_pago:=trunc(SYSDATE);
    end if; 
    v_est_periodo:= nvl(pas_snp.fu_obt_est_horario(rg_ge_snp_trans.cod_msj_swift, rg_ge_snp_trans.cod_tip_operacion, rg_ge_snp_trans.cod_sub_tip_operacion),'C');
    -- Vuelve a analizar tipo de mensaje en base a cod_msj_swift
    if  rg_ge_snp_trans.cod_msj_swift = 103 then
              rg_ge_snp_trans.ind_valor := 'S';
              
        
    elsif  rg_ge_snp_trans.cod_msj_swift = 102
                and rg_ge_snp_trans.cod_moneda = PAG_GEN.FU_OBT_MON_LOCAL
            and rg_ge_snp_trans.monto <= fug_obt_pardinamico('MTO_MAX_ACH') then
              rg_ge_snp_trans.ind_valor := 'N';
              rg_ge_snp_trans.cod_swi_suc_beneficiario     := null;
                rg_ge_snp_trans.nro_cta_suc_pte_beneficiario := null;
    elsif  rg_ge_snp_trans.cod_msj_swift = 102
                and (rg_ge_snp_trans.cod_moneda = PAG_GEN.FU_OBT_MON_LOCAL
            or rg_ge_snp_trans.monto > fug_obt_pardinamico('MTO_MAX_ACH')) then
            rg_ge_snp_trans.cod_msj_swift := 103;
            rg_ge_snp_trans.cod_tip_operacion     := '001';
            rg_ge_snp_trans.cod_sub_tip_operacion := '002';
              rg_ge_snp_trans.ind_valor := 'S';
              rg_ge_snp_trans.cod_swi_suc_beneficiario     := null;
                rg_ge_snp_trans.nro_cta_suc_pte_beneficiario := null;
     elsif  rg_ge_snp_trans.cod_msj_swift = 102
                and (rg_ge_snp_trans.cod_moneda <> PAG_GEN.FU_OBT_MON_LOCAL
            or rg_ge_snp_trans.monto > fug_obt_pardinamico('MTO_MAX_ACH')) then
            rg_ge_snp_trans.cod_msj_swift := 103;
            rg_ge_snp_trans.cod_tip_operacion     := '001';
            rg_ge_snp_trans.cod_sub_tip_operacion := '002';
              rg_ge_snp_trans.ind_valor := 'S';
              rg_ge_snp_trans.cod_swi_suc_beneficiario     := null;
                rg_ge_snp_trans.nro_cta_suc_pte_beneficiario := null;
     elsif  rg_ge_snp_trans.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_PCD' )  then
                  /*rg_ge_snp_trans.cod_tip_operacion     := '001';--BWP-1039
                  rg_ge_snp_trans.cod_sub_tip_operacion := '002';*/
                  ----
                   if nvl(v_patrocinador,'N')='S' then --SPI Fase 2--BWP-1039
                      rg_ge_snp_trans.cod_tip_operacion     := '002';
                      rg_ge_snp_trans.cod_sub_tip_operacion := '002';
                   else
                  rg_ge_snp_trans.cod_tip_operacion     := '001';
                  rg_ge_snp_trans.cod_sub_tip_operacion := '002';
                   end if;
                  rg_ge_snp_trans.ind_valor := 'S';
                  rg_ge_snp_trans.nro_ref_externa:=pas_spi.fu_obt_sig_nro_ref_externa;
                  v_fec_pago:=trunc(sysdate);
                  rg_ge_snp_trans.cod_swi_suc_beneficiario     := null;
                rg_ge_snp_trans.nro_cta_suc_pte_beneficiario := null;
     end if;
     if nvl(v_patrocinador,'N') = 'S' then--BWP-1039
         rg_ge_snp_trans.cod_swi_suc_beneficiario     := v_cod_swift_sub;
         rg_ge_snp_trans.nro_cta_suc_pte_beneficiario := v_cta_sub;
     else
         rg_ge_snp_trans.cod_swi_suc_beneficiario     := null;
         rg_ge_snp_trans.nro_cta_suc_pte_beneficiario := null;
    end if;
    --calculo de fecha sugerida y fecha operacion
     if rg_ge_snp_trans.cod_msj_swift != fug_obt_pardinamico( 'COD_SPI_PCD' ) then--pacs.008
      if rg_ge_snp_trans.cod_msj_swift=102 then
        if nvl(v_ind_habil,'S') ='S' and v_est_periodo='A' then
          v_fec_sugerida := pag_cal.fu_obt_fec_habil(trunc(sysdate),1,rg_ge_snp_trans.cod_oficina);
          v_fec_operacion := v_fec_sugerida;
         elsif nvl(v_ind_habil,'S') ='S' and v_est_periodo='N' then
             v_fec_sugerida := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1), NULL);
             v_fec_operacion := v_fec_sugerida;
         elsif nvl(v_ind_habil,'S') ='N' and v_est_periodo='N' then
             v_fec_sugerida := pag_cal.fu_obt_fec_actual(1);
             v_fec_operacion := v_fec_sugerida;
        else
              v_fec_sugerida := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1), NULL);
              v_fec_operacion := v_fec_sugerida;
        end if;
      else
         if   rg_ge_snp_trans.cod_tip_operacion= '001' and rg_ge_snp_trans.cod_sub_tip_operacion= '004' then
           if nvl(v_ind_habil,'S') ='S' and v_est_periodo='A' then
             v_fec_sugerida := pag_cal.fu_obt_fec_habil(trunc(sysdate),1,rg_ge_snp_trans.cod_oficina);
             v_fec_operacion := v_fec_sugerida;
           elsif nvl(v_ind_habil,'S') ='S' and v_est_periodo='N' then
             v_fec_sugerida := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1), NULL);
             v_fec_operacion := v_fec_sugerida;
            elsif nvl(v_ind_habil,'S') ='N' and v_est_periodo='N' then
             v_fec_sugerida := pag_cal.fu_obt_fec_actual(1);
             v_fec_operacion := v_fec_sugerida;
           else
              v_fec_sugerida := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1), NULL);
              v_fec_operacion := v_fec_sugerida;
           end if;
          else
              v_fec_sugerida := pas_snp.fu_obt_fec_transferencia(rg_ge_snp_trans.cod_msj_swift,rg_ge_snp_trans.cod_tip_operacion, rg_ge_snp_trans.cod_sub_tip_operacion, v_fec_operacion);
               if nvl(v_ind_habil,'S') ='S' and v_est_periodo='A' then
                  v_fec_sugerida := pag_cal.fu_obt_fec_habil(trunc(sysdate),1,rg_ge_snp_trans.cod_oficina);
                  v_fec_operacion := v_fec_sugerida;
               elsif nvl(v_ind_habil,'S') ='S' and v_est_periodo='N' then
                  v_fec_sugerida := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1), NULL);
                  v_fec_operacion := v_fec_sugerida;
               elsif nvl(v_ind_habil,'S') ='N' and v_est_periodo='N' then
                  v_fec_sugerida := pag_cal.fu_obt_fec_actual(1);
                  v_fec_operacion := v_fec_sugerida;
               else
                  v_fec_sugerida := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1), NULL);
                  v_fec_operacion := v_fec_sugerida;
           end if;
         end if;
      end if;
      rg_ge_snp_trans.estado  := 'A' ;
      rg_ge_snp_trans.nro_ref_externa:=null;
    else 
       v_fec_sugerida := pas_snp.fu_obt_fec_transferencia(rg_ge_snp_trans.cod_msj_swift,rg_ge_snp_trans.cod_tip_operacion, rg_ge_snp_trans.cod_sub_tip_operacion, v_fec_operacion);
       --DA-7772-cálculo de fecha_operacion (fecha valor) para las transferencias SPI 
       v_mes_sugerida        := to_number(to_char(v_fec_sugerida, 'MM'));
       v_mes_fec_cal         := to_number(to_char(v_fec_actual, 'MM'));
       if v_fec_operacion > trunc(sysdate) and v_fec_sugerida > v_fec_operacion then
       v_fec_operacion := v_fec_sugerida;
       end if;
        --DA-7772
       if v_fec_operacion < v_fec_sugerida and v_mes_sugerida <>  v_mes_fec_cal then
          v_fec_operacion:= trunc(sysdate);
       end if;
       if v_fec_operacion = v_fec_sugerida and v_mes_sugerida =  v_mes_fec_cal then
           v_fec_operacion:= trunc(sysdate);
       end if;
    end if;
    --fin de calculo de fecha sugerida y fecha operacion
     if rg_ge_snp_trans.cod_msj_swift!= fug_obt_pardinamico( 'COD_SPI_PCD' ) then
        rg_ge_snp_trans.fec_ingreso              := pag_cal.fu_obt_fec_actual(1);
     else
        rg_ge_snp_trans.fec_ingreso              :=  trunc(sysdate);
     end if;
      rg_ge_snp_trans.fec_valor := v_fec_operacion ;
      
    -- Obtiene el nro de cuenta de participante solicitante.
         if  rg_ge_snp_trans.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_PCD' )  then
             rg_ge_snp_trans.nro_cta_pte_solicitante     :=  pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad), rg_ge_snp_trans.cod_moneda);
         else
            rg_ge_snp_trans.nro_cta_pte_solicitante     :=  pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad), rg_ge_snp_trans.cod_moneda);
         end if;
          v_cta_pte_solicitante :=  pas_snp.fu_obt_cta_bancaria(rg_ge_snp_trans.nro_cta_pte_solicitante ,'C');
    
     /*--------------
      --BENEFICIARIO--
      ----------------*/
      rg_ge_snp_trans.cod_tip_doc_beneficiario := reg.cod_tip_doc_beneficiario;
      rg_ge_snp_trans.nro_doc_beneficiario := reg.nro_doc_beneficiario;
      rg_ge_snp_trans.cod_per_beneficiario := fue_obt_cod_persona(reg.nro_doc_beneficiario);
      rg_ge_snp_trans.nom_beneficiario := reg.beneficiario;
      rg_ge_snp_trans.dir_beneficiario := reg.dir_beneficiario;
      rg_ge_snp_trans.nro_cta_beneficiario :=  paw_bel.depurarAlfanumerico(reg.nro_cta_beneficiario,20);--reg.nro_cta_beneficiario;
         --valida si la cuenta beneficiaria no esta habilitada para recibir transferencias
        select count(*)
        into v_existe
        from ge_snp_cta_restringidas re
        where instr(rg_ge_snp_trans.nro_cta_beneficiario,re.nro_cuenta)>0
        and re.cod_swi_entidad=(case v_patrocinador
                                 when 'S' then
                                     v_cod_swift_sub
                                 else
                                     v_cod_swift
                                 end)
       and re.estado='A';
       
       if v_existe>0 then
          p_cod_error:='PRO_ERR_CTAINH';
          p_error := 'ERROR. CUENTA BENEFICIARIA NO ESTA HABILITADA PARA RECIBIR TRANSFERENCIAS';
          PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
        return;
       end if;
      if rg_ge_snp_trans.cod_tip_doc_beneficiario is null then
        p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
        p_error := 'ERROR. CODIGO DE TIPO DE DOCUMENTO BENEFICIARIO NO PUEDE SER NULO';
        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
        return;
      end if;
      --
      if rg_ge_snp_trans.nro_doc_beneficiario is null then
        p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
        p_error := 'ERROR. NUMERO DE DOCUMENTO BENEFICIARIO NO PUEDE SER NULO';
        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
        return;
      end if;
      --
      if rg_ge_snp_trans.nom_beneficiario is null then
        p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
        p_error := 'ERROR. NOMBRE BENEFICIARIO NO PUEDE SER NULO';
        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
        return;
      end if;

      if rg_ge_snp_trans.nro_cta_beneficiario is null then
        p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
        p_error := 'ERROR. NUMERO DE CUENTA BENEFICIARIO NO PUEDE SER NULO';
        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
        return;
      end if;

     --Si es 102 y la moneda destino es en USD
     if rg_ge_snp_trans.cod_msj_swift= 102
         and rg_ge_snp_trans.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL then
         p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
         p_error := 'ERROR. para MT 102 - Debe ser moneda local';
         PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
         return;
     end if;
      --Hallo el swift de la entidad de destino
      begin
        select b.cod_swift
          into rg_ge_snp_trans.cod_swi_pte_beneficiario
          from gv_snp_participantes b
         where b.cod_swift= v_cod_swift
           and b.cod_persona != fug_obt_per_entidad;
      exception
          when no_data_found then
            --controla subparticipantes
           begin 
               --Controla patrocinadores
                select p.cod_swift_sub
                  into v_cod_swift
                  from ge_snp_patrocinador_det p
                 where p.cod_swift_sub = reg.cod_swift
                   and estado = 'S';
                   exception 
                      when no_data_found then
                       p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                        p_error := 'ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.ent_bca_beneficiario||': '||sqlerrm;
                        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                        return;
                      when others  then
                        p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                        p_error := 'ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.ent_bca_beneficiario||': '||sqlerrm;
                        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
             return;
                 end;
          when others then
             p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
             p_error := 'ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.ent_bca_beneficiario||': '||sqlerrm;
             PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
             return;
      end;
      
      --  Si es BCP hay que cambiar el sub tipo de operación a 005
      IF rg_ge_snp_trans.cod_swi_pte_beneficiario = nvl(fug_obt_pardinamico('SNP_BIC_BCP'),'X') THEN
         rg_ge_snp_trans.cod_sub_tip_operacion := v_cod_sub_tip_ope_bcp; -- DDSI-62
         -- No se pueden hacer transferencias por lotes al BCP
         IF rg_ge_snp_trans.cod_tip_operacion = '011' THEN
            p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
            p_error := 'La prioridad de envío no está permitida para transferencias al BCP.';
            PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
            return;
         END IF;
      END IF;
      if  rg_ge_snp_trans.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_PCD' )  then
          rg_ge_snp_trans.nro_cta_pte_beneficiario :=pas_spi.fu_obt_cta_ban_participante(rg_ge_snp_trans.cod_swi_pte_beneficiario,  rg_ge_snp_trans.cod_moneda) ;
      else
          rg_ge_snp_trans.nro_cta_pte_beneficiario :=pas_snp.fu_obt_cta_ban_participante(rg_ge_snp_trans.cod_swi_pte_beneficiario,  rg_ge_snp_trans.cod_moneda) ;
     end if;

      if rg_ge_snp_trans.nro_cta_pte_beneficiario is null then
        p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
        p_error := 'ERROR. Cta. Pte. Beneficiario nulo para código swift: '
        ||rg_ge_snp_trans.cod_swi_pte_beneficiario||' Moneda: '||rg_ge_snp_trans.cod_moneda;
        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
        return;
      end if;
    
      v_concepto:= null;
      v_lon_nro_referencia:=0;
      v_lon_nro_factura:=0;
      v_lon_concepto:=0;
      v_lon_cadena:=0;
      --Hallamos las longitudes.
      v_lon_nro_referencia:= length(reg.ref_facturas);
      v_lon_nro_factura:= length(reg.nro_factura);
      v_lon_concepto:= length(reg.concepto);
      --***Verificamos Ref_facturas***
      if nvl(v_lon_nro_referencia,0) > 0 and nvl(v_lon_nro_referencia,0)<= 100 then
         --Si no es nulo y es menor o igual a 100 tomamos todas las posiciones
         v_concepto:= trim(substr(reg.ref_facturas,1,v_lon_nro_referencia));
         v_lon_cadena:= length(v_concepto);  
      elsif nvl(v_lon_nro_referencia,0) > 0 and nvl(v_lon_nro_referencia,0) > 100 then
         --Sino es nulo y tiene mas de 100 caracteres, cortamos en 100
         v_concepto:= trim(substr(reg.ref_facturas,1,100));
         v_lon_cadena:= length(v_concepto); 
      end if;
      --***Verificamos Concepto***
      if nvl(v_lon_cadena,0) < 100 then
        v_disponible:= 100 - nvl(v_lon_cadena,0);
        if nvl(v_lon_concepto,0) > 0 then 
           --Si no esta nulo el campo concepto.
          v_concepto:= trim(v_concepto||' '|| substr(reg.concepto,1,v_disponible -1));
          v_lon_cadena:= length(v_concepto);
        end if;
      
      end if;
      --Verificamos NRO_FACTURA 
      if nvl(v_lon_cadena,0) < 100 then
          v_disponible:=0;
          -- 100 + 1 Espacio por concepto
          v_disponible:= 101 - nvl(v_lon_cadena,0);
          if nvl(v_lon_nro_factura,0) > 0 then 
            if v_disponible >= v_lon_nro_factura then -- DYDMR-4554 -- 07/2016 -- Solo si la longitud disponible es mayor o igual al numero de factura
             v_concepto:= trim(v_concepto||' '|| substr(reg.nro_factura,1,v_disponible -1));
            end if;
          end if;
      end if;
       -- manejo de campo multilínea
      v_concepto_tra             := paw_bel.depurarAlfanumerico(reg.concepto,30);
      v_concepto_tra := substr(v_concepto_tra,1,31);--el tag 72 acepta hasta 36 caracteres
      if (instr(v_concepto_tra,'^',-1) = length(trim(v_concepto_tra))) then
          v_concepto_tra := substr(v_concepto_tra,1,length(trim(v_concepto_tra))-1);
       end if;
       v_concepto_tra := replace(v_concepto_tra,'^',pas_snp.fu_obt_salto);
       v_concepto_tra :=  '/BNF/'||pas_snp.fu_val_cadena(v_concepto_tra);
      --Finalmente cortamos a 100 ya que es el máximo. (Le quitamos espacio sino se utliza, dos espacios tiene)
      rg_ge_snp_trans.observacion := v_concepto_tra;
      --******************************************************************
      rg_ge_snp_trans.concepto:='Trx. via BCP Nro Re'||rg_ge_snp_trans.nro_referencia;
      begin
        select m.prioridad
          into rg_ge_snp_trans.prioridad
          from ge_snp_par_mensajes m
         where m.cod_msj_swift = rg_ge_snp_trans.cod_msj_swift
           and m.cod_tip_operacion = rg_ge_snp_trans.cod_tip_operacion
           and m.cod_sub_tip_operacion = rg_ge_snp_trans.cod_sub_tip_operacion;
      exception
          when others then
             p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
             p_error := 'ERROR AL HALLAR PRIORIDAD: '||sqlerrm;
             PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
             return;
      end;
       if pae_cnf.fu_obt_est_modulo(3) IN (1,6) then----DA-7022
          prg_rol_savepoint('sipap');
          p_cod_error:='PRO_ERR_PROCIE';
          p_error := 'Error :Sistema no permite el proceso';
          PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
          return;
       end if;
      begin
         
         pas_snp.pr_ins_transferencias(rg_ge_snp_trans);
         if pas_snp.fu_obt_cod_error <> 0 then
           p_cod_error:='COD_INS_TRANSFE';
           p_error := pas_snp.fu_obt_msj_error;
           PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
           return;
         end if;
      exception
        when others then
           p_cod_error:='COD_INS_TRANSFE';
           p_error := 'ERROR AL INSERTAR TRANSFERENCIA: '||sqlerrm;
           PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
           return;
      end;
      if pae_cnf.fu_obt_est_modulo(3) IN (1,6) then----DA-7022
          prg_rol_savepoint('sipap');
          p_cod_error:='PRO_ERR_PROCIE';
          p_error := 'Error :Sistema no permite el proceso';
          PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
          return;
       end if;
         -- Genera el Mensaje Swift    
         begin
           if rg_ge_snp_trans.cod_msj_swift in ( 102,8) then
             rg_ge_snp_trans.msj_swift := NULL;
           elsif rg_ge_snp_trans.cod_msj_swift= 103 then
             rg_ge_snp_trans.msj_swift := pas_snp.fu_obt_msj_mt103(rg_ge_snp_trans.nro_referencia,
                                                                   'N');
             if pas_snp.fu_obt_cod_error <> 0 then
               p_cod_error := 'PRO_AUT_ERR_PAG_PROVEEDORES';
               p_error     := 'OBTENER MENSAJERÍA: ' ||
                              pas_snp.fu_obt_msj_error;
               PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
               return;
             end if;
             pre_cam_for_numerico('.,');
           end if;
         exception
           when others then
             p_cod_error := 'PRO_AUT_ERR_PAG_PROVEEDORES';
             p_error     := 'OBTENER MENSAJERÍA: ' || sqlerrm;
             PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
             return;
         end;
        -- Actualiza mensaje swift en caso que se requiera
         update ge_snp_transferencias
            set msj_swift = rg_ge_snp_trans.msj_swift
          where nro_referencia = rg_ge_snp_trans.nro_referencia;

      if p_error is null then
        -- Cambia fecha para ACH
        if rg_ge_snp_trans.cod_msj_swift=102 then
          v_fec_pago := pag_cal.fu_obt_fec_habil(v_fec_actual + 1,1,1);
        end if;
        if pae_cnf.fu_obt_est_modulo(3) IN (1,6) then----DA-7022
          prg_rol_savepoint('sipap');
          p_cod_error:='PRO_ERR_PROCIE';
          p_error := 'Error :Sistema no permite el proceso';
          PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
          return;
       end if;
        begin
           update ge_pag_proveedores
              set nro_referencia = rg_ge_snp_trans.nro_referencia,
                  nro_documento= rg_ge_snp_trans.nro_referencia,
                  estado = 'N',
                  nro_pago        = to_char(pag_cal.fu_obt_fec_actual(1),'yymmdd')||replace(to_char(sysdate,'hh24:mi:ss'),':','')||'1',
                  nro_lote        = to_number(v_nro_lote)+1,
                  fec_pago        = v_fec_pago
            where rowid= reg.rowid;
        exception
          when others then
             p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
             p_error := 'ERROR AL ACTUALIZAR PAGO: '||sqlerrm;
             PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
             return;
        end;

        if reg.nro_con_cambio is not null then
           begin
              v_can_con_cambio:=0;

              select count(a.nro_operacion)
                into v_can_con_cambio
                from lc_ope_pendientes a
               where a.nro_operacion=reg.nro_con_cambio
                 and a.liquidado='S'
                 and rownum=1
                 and trunc(a.fec_insercion) = trunc(sysdate);
           exception
              when no_data_found then
                 v_can_con_cambio:=0;
           end;

           if NVL(v_can_con_cambio,0) > 0 then
              p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
              p_error := 'Contrato de Cambios ya fué Liquidado. Nro: '||v_nro_con_cambio;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
              return;
           end if;
        end if;
      else
        return;
      end if;
      v_fec_operacion       :=p_fec_pago;--SETEO
      v_patrocinador:='N';
      v_est_periodo:= null;
   end loop;
   -- Generar Movimientos Débito
   if p_error is null then
      for reg in c_deb loop
         pas_snp.pr_ini_registros;
         pas_snp.pr_ini_variables;
         rg_ge_snp_trans.nro_referencia           := reg.nro_referencia;
         rg_ge_snp_trans.nro_sec_lote             := reg.nro_sec_lote;
         rg_ge_snp_trans.cod_modulo               := reg.cod_modulo;
         rg_ge_snp_trans.cod_modalidad            := reg.cod_modalidad;
         rg_ge_snp_trans.cod_oficina              := reg.cod_oficina;
         rg_ge_snp_trans.cod_tip_operacion        := reg.cod_tip_operacion;
         rg_ge_snp_trans.cod_sub_tip_operacion    := reg.cod_sub_tip_operacion;
         rg_ge_snp_trans.cod_msj_swift            := reg.cod_msj_swift;
         rg_ge_snp_trans.fec_recepcion            := reg.fec_recepcion;
         rg_ge_snp_trans.fec_ingreso              := reg.fec_ingreso;
         rg_ge_snp_trans.fec_valor                := reg.fec_valor;
         rg_ge_snp_trans.fecha                    := reg.fecha;
         rg_ge_snp_trans.hora                     := reg.hora;
         rg_ge_snp_trans.cod_usuario              := reg.cod_usuario;
         rg_ge_snp_trans.cod_moneda               := reg.cod_moneda;
         rg_ge_snp_trans.monto                    := reg.monto;
         rg_ge_snp_trans.cod_per_solicitante      := reg.cod_per_solicitante;
         rg_ge_snp_trans.nom_solicitante          := reg.nom_solicitante;
         rg_ge_snp_trans.dir_solicitante          := reg.dir_solicitante;
         rg_ge_snp_trans.nro_doc_solicitante      := reg.nro_doc_solicitante;
         rg_ge_snp_trans.nro_cta_solicitante      := reg.nro_cta_solicitante;
         rg_ge_snp_trans.cod_swi_pte_solicitante  := reg.cod_swi_pte_solicitante;
         rg_ge_snp_trans.nro_cta_pte_solicitante  := reg.nro_cta_pte_solicitante;
         rg_ge_snp_trans.cod_per_beneficiario     := reg.cod_per_beneficiario;
         rg_ge_snp_trans.nom_beneficiario         := reg.nom_beneficiario;
         rg_ge_snp_trans.dir_beneficiario         := reg.dir_beneficiario;
         rg_ge_snp_trans.nro_doc_beneficiario     := reg.nro_doc_beneficiario;
         rg_ge_snp_trans.nro_cta_beneficiario     := reg.nro_cta_beneficiario;
         rg_ge_snp_trans.cod_swi_pte_beneficiario := reg.cod_swi_pte_beneficiario;
         rg_ge_snp_trans.nro_cta_pte_beneficiario := reg.nro_cta_pte_beneficiario;
         rg_ge_snp_trans.cod_swi_suc_beneficiario  :=reg.cod_swi_suc_beneficiario;
         rg_ge_snp_trans.nro_cta_suc_pte_beneficiario:=reg.nro_cta_suc_pte_beneficiario;
         rg_ge_snp_trans.concepto                 := reg.concepto;
         rg_ge_snp_trans.observacion              := reg.observacion;
         rg_ge_snp_trans.tip_cargo                := reg.tip_cargo;
         rg_ge_snp_trans.ind_valor                := reg.ind_valor;
         rg_ge_snp_trans.nro_ref_externa          := reg.nro_ref_externa;
         rg_ge_snp_trans.situacion                := reg.situacion;
         rg_ge_snp_trans.estado                   := reg.estado;
         rg_ge_snp_trans.prioridad                := reg.prioridad;
         rg_ge_snp_trans.nro_operacion            := reg.nro_operacion;
         rg_ge_snp_trans.tip_mensaje              := reg.tip_mensaje;
         rg_ge_snp_trans.error                    := reg.error;
         rg_ge_snp_trans.origen                   := reg.origen;
         rg_ge_snp_trans.plataforma               := reg.plataforma;
         rg_ge_snp_trans.indemnizado              := reg.indemnizado;
         rg_ge_snp_trans.msj_swift := reg.msj_swift;
         v_cod_mon_debito   := fug_obt_mon_cta(rg_ge_snp_trans.nro_cta_solicitante) ;
 
      v_est_periodo:= nvl(pas_snp.fu_obt_est_horario(rg_ge_snp_trans.cod_msj_swift, rg_ge_snp_trans.cod_tip_operacion, rg_ge_snp_trans.cod_sub_tip_operacion),'C');
       if pae_cnf.fu_obt_est_modulo(3) IN (1,6) then----DA-7022
          prg_rol_savepoint('sipap');
          p_cod_error:='PRO_ERR_PROCIE';
          p_error := 'Error :Sistema no permite el proceso';
          PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
          return;
       end if;
      --Controla horario cierre 
      pas_spi.lp_ver_horario(3);
      --Controla ingreso de movimiento en caso de SPI
      if pas_spi.g_es_mov_noc='S' and  rg_ge_snp_trans.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_PCD' ) then
       prg_gen_mov_noc_spi(rg_ge_snp_trans.monto,
                                       rg_ge_snp_trans.nro_cta_solicitante,
                                       v_cta_pte_solicitante,
                                       v_cod_mon_debito,
                                       rg_ge_snp_trans.cod_msj_swift,
                                       rg_ge_snp_trans.cod_tip_operacion,
                                       rg_ge_snp_trans.cod_sub_tip_operacion,
                                       rg_ge_snp_trans.nro_referencia,
                                       rg_ge_snp_trans.nro_ref_externa,
                                       rg_ge_snp_trans.cod_swi_pte_beneficiario,
                                       'E',
                                       'N',
                                       null,
                                       null,
                                       null,
                                       null,
                                       null,
                                       v_cod_respuesta,
                                       v_desc_respuesta);
                           IF v_cod_respuesta=91 then --en cierre --DA-7022

                            p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                            p_error := 'Error :'||pas_snp.fu_obt_msj_error;
                            PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                            p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                            p_cod_persona  => v_cod_empresa,
                            p_nro_cuenta   => null);
                            return;
                       
                         elsif v_cod_respuesta != 0 THEN
                           
                           p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                           p_error := 'Error :'||pas_snp.fu_obt_msj_error;
                           PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                           return;
                         END IF;
    else 
        if pae_cnf.fu_obt_est_modulo(3) IN (1,6) then----DA-7022
          prg_rol_savepoint('sipap');
          p_cod_error:='PRO_ERR_PROCIE';
          p_error := 'Error :Sistema no permite el proceso';
          PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
          return;
        end if;
        if    rg_ge_snp_trans.fec_valor = rg_ge_snp_trans.fec_ingreso and
                   ( pas_snp.fu_obt_fec_ult_operacion = rg_ge_snp_trans.fec_valor and rg_ge_snp_trans.cod_msj_swift!=fug_obt_pardinamico( 'COD_SPI_PCD' )) or (rg_ge_snp_trans.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_PCD' ) and rg_ge_snp_trans.fec_valor = trunc(sysdate))
                    then
         begin
           pag_cta.pr_set_nro_documento3(p_nro_documento);
           /*---------------------------------------------------*/
           declare
            v_cod_error  number;
            v_error     varchar2(4000);
           begin
             --UES-1849 Se agrego llamada a el nuevo prc que inserta los mov.
             pag_prv.pr_pro_transferencia_prv(rg_ge_snp_trans, v_cod_error, v_error, v_cod_empresa);
             if v_cod_error <> 0 then
                prg_rol_savepoint('sipap'); 
                p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                p_error  := 'Error: ' || v_cod_error || ' - '||v_error ;
                PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                return;
             end if;
           exception
             when others then
               prg_rol_savepoint('sipap'); 
               p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
               p_error  := 'Error al ejecutar pas_snp.pr_pro_transferencia_dev ' || sqlerrm;
               PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
               return; 
           end;
           /*------------------------------------------------------*/     
                
                      pas_snp.pr_set_transferencias(rg_ge_snp_trans);
                      if pas_snp.fu_obt_cod_error <> 0 then
                         p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                         p_error := 'Error :'||pas_snp.fu_obt_msj_error;
                         PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                         return;
                      end if;
                if pas_snp.fu_ver_mov_duplicados(rg_ge_snp_trans) > 0 then
                   pas_snp.pr_ini_workflow(rg_ge_snp_trans);
                   rg_ge_snp_trans.estado := 'S';
                   pas_snp.pr_set_transferencias(rg_ge_snp_trans);
                    if pas_snp.fu_obt_cod_error <> 0 then
                           p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                           p_error := 'Error :'||pas_snp.fu_obt_msj_error;
                           PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                           return;
                     end if;
                end if;
            exception
                 when others then
                        p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
                        p_error := 'Error :'||pas_snp.g_msj_error;
                        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                   return;
            end;
            if pas_snp.g_cod_error != 0 then
               p_cod_error:='PRO_AUT_ERR_PAG_PROVEEDORES';
               p_error := pas_snp.g_msj_error;
               PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
               return;
            else
              --Sino hubo error, actualizamos la 503 para Nro_Documento3
              begin

              update ge_movimientos
                   set nro_documento3 = p_cod_ente
               where fecha = pag_cal.fu_obt_fec_actual(1)
                 and cod_usuario = p_usuario
                 and nro_documento=rg_ge_snp_trans.nro_referencia
                 and reversado ='N'
                 and cod_transaccion= 503;
                exception
                      when others then
                        p_cod_error:='COD_ACT_TRANMOV';
                        p_error := 'Error Mov.REf.:'||rg_ge_snp_trans.nro_referencia||' Hora:'||rg_ge_snp_trans.hora|| ' '||sqlerrm;
                        PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                        return;
                end;
              -- Verifica estado, segun tipo de mensaje para disponibilizar al MS de SPI
              if  rg_ge_snp_trans.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_PCD' )  then
                  v_estado := 'U';
              else
                  v_estado := 'A';
              end if;
               update ge_snp_transferencias
                  set estado = nvl( v_estado, estado )
                where nro_referencia = rg_ge_snp_trans.nro_referencia;
            end if;
      else 
            if  rg_ge_snp_trans.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_PCD' )  then
                  v_estado := 'U';
              else
                  v_estado := 'A';
              end if;
               update ge_snp_transferencias
                  set estado = nvl( v_estado, estado )
                where nro_referencia = rg_ge_snp_trans.nro_referencia;
      end if;
              -- Enviar Swift 103 
           if p_error is null
             and p_cod_ente is not null
                and p_usuario is not null
                   and p_fec_pago is not null
                      and p_nro_archivo is not null and rg_ge_snp_trans.cod_msj_swift in (103) then
          
        if    rg_ge_snp_trans.fec_valor = rg_ge_snp_trans.fec_ingreso and
                   ( pas_snp.fu_obt_fec_ult_operacion = rg_ge_snp_trans.fec_valor)
                    then
             if pas_snp.fu_obt_est_horario( rg_ge_snp_trans.cod_msj_swift,
                                     rg_ge_snp_trans.cod_tip_operacion,
                                     rg_ge_snp_trans.cod_sub_tip_operacion
                                   ) = 'A'
                     then --Si el horario está VIGENTE en BCP
               pas_snp.pr_gen_arc_swift(rg_ge_snp_trans.nro_referencia, 'N','A') ;
               if pas_snp.g_cod_error != 0 then
                       p_cod_error:='COD_ERR_ENVSWIF';
                       p_error := pas_snp.g_msj_error;
                       PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
                       return;
               end if;
               end if; 
           end if; 
           end if;
      end if;
      end loop;
      else
        return;
      end if;
 
EXCEPTION
   when others then
     p_cod_error := 'PRO_AUT_ERR_PAG_PROVEEDORES';
     if p_error is null then
       p_error := substr('ERROR EN LA GENERACION DE TRANSFERENCIAS: '||sqlerrm, 1, 1000);
       PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
       return;
     else
       p_error := 'Error ' || sqlerrm;
       PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_PAG_SNP_DEV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || p_error ) ,
                           p_cod_persona  => v_cod_empresa,
                           p_nro_cuenta   => null);
       return;
     end if;
END PR_PRO_PAG_SNP_DEV;
/* NVB-2232-Borra Datos de la tabla GE_PAG_PROVEEDORES_TMP */
PROCEDURE PR_ELI_PROV_TMP_DEV
 (P_COD_EMPRESA IN NUMBER,
  P_FEC_PROCESO IN DATE DEFAULT NULL,
  P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 )
 IS
v_usuario             ba_usuarios.cod_usuario%TYPE := substr(user,  1, 10);
/* Borra los datos procesados del temporal DE PROVEEDORES */
begin
  --DDSI-1679 USER tiene en cuenta el usuario de itgf y tambien de digitales
  v_usuario := USER;
   if v_usuario in ('HBANK', 'BBVAAPIUSR') then
       v_usuario := 'HBANK'; --Solo se cambia con digitales ya que el registro se da desde hbank
  end if;

    DELETE GE_PAG_PROVEEDORES_TMP
     WHERE (COD_ENTE = p_cod_empresa or COD_ENTE is null)
       --AND USU_INSERCION = USER Se comenta ya que no tiene en cuenta el usuario de EMA BBVAAPIUSR
       AND USU_INSERCION = v_usuario -- tratado en el DDSI-1679
       AND (P_FEC_PROCESO IS NULL OR TRUNC(FEC_INSERCION) = TRUNC(P_FEC_PROCESO))
       AND nvl(NRO_ARCHIVO, 0) = nvl(P_NRO_ARCHIVO, 0);
exception
 When others then
  RAISE_APPLICATION_ERROR(-20010,'Borrar GE_PAG_PROVEEDORES_TMP ');
end PR_ELI_PROV_TMP_DEV;

/*NVB-2232- Borra datos del temporal GE_PAG_FACTURAS_TMP */
PROCEDURE PR_ELI_FAC_TMP_DEV
 (P_COD_EMPRESA IN NUMBER,
  P_FEC_PROCESO IN DATE DEFAULT NULL,
  P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
 )
 IS
  v_usuario             ba_usuarios.cod_usuario%TYPE := substr(user,  1, 10);
/* Borra los datos procesados del temporal FACTURAS DE PROVEEDORES */
begin
  v_usuario := USER;
   if v_usuario in ('HBANK', 'BBVAAPIUSR') then
       v_usuario := 'HBANK'; --Solo se cambia con digitales ya que el registro se da desde hbank
   end if;

    DELETE GE_PAG_PRO_FACTURAS_TMP
     WHERE COD_ENTE = p_cod_empresa
       AND USU_INSERCION = v_usuario
       AND (P_FEC_PROCESO IS NULL OR TRUNC(FEC_INSERCION) = TRUNC(P_FEC_PROCESO))
       AND nvl(NRO_ARCHIVO, 0) = nvl(P_NRO_ARCHIVO, 0);
exception
 When others then
  RAISE_APPLICATION_ERROR(-20010,'Borrar GE_PAG_PRO_FACTURAS_TMP ');
end PR_ELI_FAC_TMP_DEV;

/*UES-1849 - Se agrega un nuevo prc que inserta mov. cuando es trans interbancaria*/
PROCEDURE PR_PRO_TRANSFERENCIA_PRV(rg_msj_mov_tra IN OUT PAS_SNP.rg_msj,
                                   p_cod_error IN OUT number,
                                   p_error        IN OUT VARCHAR2,
                                   p_cod_empresa   varchar2) IS

  /*para el mov*/
 v_cod_usuario  ge_movimientos.cod_usuario%type;
 
 ----
 v_nro_cta_debito  ge_cuentas.nro_cuenta%type   := NULL;
 v_cod_mon_local       varchar2(3)     := pag_gen.fu_obt_mon_local;
 v_nro_documento2    ge_movimientos.nro_documento2%type  := NULL;
 v_mon_origen      ge_movimientos.cod_moneda%type    := NULL;
 v_ind_cob_cargos    varchar2(1) := 'S';
 v_nro_cta_credito   ge_cuentas.nro_cuenta%type   := NULL;
 v_swi_participante  ge_snp_transferencias.cod_swi_pte_solicitante%type := NULL;
 v_concepto          ge_movimientos.concepto%type := NULL;
 v_det_msj_error     ge_snp_transferencias.error%type := null;
 
 rg_deb              pag_cta.rg_ctas := NULL;
 rg_cre              pag_cta.rg_ctas := NULL;
 v_hora              ge_movimientos.hora%type            := NULL;
 rg_pte              pag_cta.rg_ctas := NULL;
 rg_movi             ge_movimientos%rowtype       := NULL;
 
 v_nro_secuencia     ge_movimientos.nro_secuencia%type   := 0;
 
 v_cod_ofi_origen       ge_movimientos.cod_ofi_origen%type;
 
 v_tra_padre         ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_padre;
 v_mod_padre         ge_movimientos.cod_mod_padre%type   := pas_snp.fu_obt_cod_mod_padre;
 v_mad_padre         ge_movimientos.cod_mad_padre%type   := pas_snp.fu_obt_cod_mad_padre;
 v_tra_debito        ge_movimientos.cod_transaccion%type := NULL;
 v_tra_credito       ge_movimientos.cod_transaccion%type := NULL;
 
 v_tip_mov_debito    varchar2(1) := 'D';
 v_tip_mov_credito   varchar2(1) := 'C';
 
 -- Retorno de verificación de operaciones
 v_est_cuenta        ge_cuentas.estado%type;    -- Estado Cta.
 v_sal_disponible    ge_movimientos.monto%type; -- Sal.Dispon.
 v_procesa           varchar2(1) := 'N';
 
 
 v_mto_debito        ge_movimientos.monto%type           := NULL;
 v_mto_credito       ge_movimientos.monto%type           := NULL;
 
 v_nro_con_cambio    lc_ope_pendientes.nro_operacion%type  := NULL;
 v_cot_destino       ge_movimientos.cotizacion%type    := NULL;
 
 
 v_mto_destino       ge_movimientos.monto%type         := NULL;
 v_mon_destino       ge_movimientos.cod_moneda%type    := NULL;
 
 v_cot_origen        ge_movimientos.cotizacion%type    := NULL;
 v_mto_equ_local     ge_movimientos.mto_equ_local%type := NULL;
 v_cotizacion        ge_movimientos.cotizacion%type    := NULL;

 FUNCTION fu_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type )return varchar2;
 
 PROCEDURE lp_reg_mov_transferencia_prv;
 
 FUNCTION fu_obt_hora(p_cod_usuario varchar2) return varchar2;
 
 FUNCTION fu_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type)
    return varchar2 is
    v_nro_sec  number;
    v_can_user number;
    v_nro_user number;
    v_user     ba_usuarios.cod_usuario%type;

  BEGIN
    select count(*)
      into v_can_user
      from ba_cod_referencias
     where dominio     = 'USU_MOV_SERVICIO'
       and abreviatura = p_tip_user;

    v_nro_sec  := fue_obt_sig_secuencia('S_SER_PAYMPV');
    v_nro_user := mod(v_nro_sec, v_can_user);
    v_user     := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO', v_nro_user, p_tip_user);
    return v_user;
  EXCEPTION
    WHEN OTHERS THEN
     p_cod_error := 35;
     PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || 'P_TIP_USER: '|| p_tip_user || ' ERROR EN PAG_PRV.PR_PRO_TRANSFERENCIA_PRV - FU_OBT_MOV_USER ' || SQLERRM),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                           
     
     RETURN NULL;
  END;
 
 FUNCTION fu_obt_hora(p_cod_usuario varchar2) return varchar2 is
    v_hora        ge_movimientos.hora%type;
    v_nro_sec     number;
    v_nro_hor     number;
    v_ind_usuario number;

  BEGIN
    if instr(p_cod_usuario, '_', 1) = 0 then
      v_ind_usuario := 0;
    else
      v_ind_usuario := substr(p_cod_usuario, instr(p_cod_usuario, '_', 1) + 1, 2);
    end if;

    if v_ind_usuario > 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_movpaympv' /*||'_'*/|| v_ind_usuario);
    elsif v_ind_usuario = 0 then
      v_nro_sec := fue_obt_sig_secuencia('S_HOR_MOVPAYMPV');
    end if;

    v_nro_hor := mod(v_nro_sec, 86400);

    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

    return v_hora;
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 36;
      PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_cod_error || ' - ' || 'P_COD_USUARIO: '|| p_cod_usuario ||' ERROR EN PAG_PRV.PR_PRO_TRANSFERENCIA_PRV - FU_OBT_HORA ' || SQLERRM),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                           
     
     RETURN NULL;
      raise_application_error(-20000, 'No se puede obtener la hora del movimiento. ' || sqlerrm);
  END;
 
 PROCEDURE lp_reg_mov_transferencia_prv
   IS
 
 begin
   if p_cod_error = 0 and rg_msj_mov_tra.monto <> 0 then
      --inicializamos
      v_cod_usuario := null;
      
      begin
        if pas_snp.fu_obt_cod_error = 0 and rg_msj_mov_tra.monto <> 0 then
          if pas_snp.fu_val_es_enviado ( rg_msj_mov_tra ) then
            if rg_msj_mov_tra.cod_msj_swift != 104 then
              v_nro_cta_debito   := rg_msj_mov_tra.nro_cta_solicitante;
              v_mon_origen       := fug_obt_mon_cta (v_nro_cta_debito);
              
              if rg_msj_mov_tra.cod_servicio is not null then
                -- Si la mensajería corresponde a un Cobro de Servicios
                -- se debe verificar si se cobrarán cargos, por defecto no se cobrarán cargos a los Servicios.
                v_ind_cob_cargos :=  nvl( fug_obt_val_par_ente( 'SNP_COB_CARGOS',
                                                                'SNP_COD_SERVICIO',
                                                                rg_msj_mov_tra.cod_servicio
                                                              ), 'N'
                                        );
              end if;
              v_nro_cta_credito  := pas_snp.fu_obt_cta_bancaria( rg_msj_mov_tra.nro_cta_pte_solicitante, 'C' );
              v_swi_participante := rg_msj_mov_tra.cod_swi_pte_beneficiario;
             if rg_msj_mov_tra.cod_msj_swift != fug_obt_pardinamico( 'COD_SPI_PCD' ) then--pacs.008
                v_concepto := pas_snp.fu_obt_mov_concepto('M', rg_msj_mov_tra.origen, rg_msj_mov_tra.nro_referencia);
             else
               v_concepto :=rg_msj_mov_tra.nro_ref_externa;
             end if;
             if pas_snp.fu_obt_cod_error <> 0 then
                pas_snp.pr_set_texto ( v_det_msj_error,  pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
                p_cod_error := 4;
                p_error     :=  v_det_msj_error;
                PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                
                return;
                
             end if;
              
            end if;
          end if;
        end if;
      EXCEPTION
        WHEN OTHERS THEN
           p_cod_error := 3;
           p_error     := 'bloque 1 ' || SQLERRM;  
           return;  
      end;
      
       ------------------------------------------------------------------
          /**/-- D A T O S   D E   L A   C U E N T A   D E   D E B I T O
       ------------------------------------------------------------------
       begin
         if pas_snp.g_cod_error = 0 then
           --inicializacion
           rg_deb := NULL;
           
           begin
            pag_cta.pr_ver_operacion( v_nro_cta_debito,     -- Nro.Cta.
                                       v_tra_padre,          -- Trx. Padre - Transferencia entre cuentas
                                       v_mod_padre,          -- Mod.Padre
                                       v_mad_padre,          -- Mad.Padre
                                       v_tip_mov_debito,     -- Tip.Mov.
                                       v_mon_origen,         -- Cod.Mon.
                                       0,                    -- Monto
                                       rg_deb.cod_oficina,   -- Ofic.Orig.
                                       rg_deb.cod_modulo,    -- Mod.Hijo
                                       rg_deb.cod_modalidad, -- Mad.Hijo
                                       v_est_cuenta,         -- Estado Cta.
                                       v_sal_disponible,     -- Sal.Dispon.
                                       v_procesa             -- Procesa
                                     );
             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                p_cod_error := pag_cta.fu_obt_cod_error;
                p_error := 'Error pag_cta.pr_ver_operacion 1 ' ||  pag_cta.fu_obt_msj_error;
                PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                return;
             end if;
           exception
             when others then
               p_cod_error := 6;
               p_error     := 'Error al verificar cuenta 1' || SQLERRM;  
               return;
           end;
           
           --validamos  la cuenta
           if not ( rg_deb.cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39, 334 ) ) then
              p_cod_error := 7;
              p_error := 'Modalidad de la cuenta no permite esta operación';
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return;
           end if;
           -- pago a proveedores 
              v_tra_debito := 7503;           
              rg_deb := pag_cta.g_ctas;
         end if;
       EXCEPTION
        WHEN OTHERS THEN
           p_cod_error := 5;
           p_error     := 'bloque 2 ' || SQLERRM;  
           return;   
       end;
       
       ------------------------------------------------------------------
        /**/-- D A T O S   D E   L A   C U E N T A   D E   C R E D I T O
       ------------------------------------------------------------------
       begin
         if pas_snp.g_cod_error = 0 then
           --inicializamos
           rg_cre := NULL;
           begin
           pag_cta.pr_ver_operacion( v_nro_cta_credito,   -- Nro.Cta.
                                       v_tra_padre,         -- Trx. Padre - Transferencia entre cuentas
                                       v_mod_padre,         -- Mod.Padre
                                       v_mad_padre,         -- Mad.Padre
                                       v_tip_mov_credito,   -- Tip.Mov.
                                       rg_cre.cod_moneda,   -- Cod.Mon.
                                       0,                   -- Monto
                                       rg_cre.cod_oficina,  -- Ofic.Orig.
                                       rg_cre.cod_modulo,   -- Mod.Hijo
                                       rg_cre.cod_modalidad,-- Mad.Hijo
                                       v_est_cuenta,        -- Estado Cta.
                                       v_sal_disponible,    -- Sal.Dispon.
                                       v_procesa            -- Procesa
                                     );
             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                p_cod_error := pag_cta.fu_obt_cod_error;
                p_error := 'Error pag_cta.pr_ver_operacion 2 ' || pag_cta.fu_obt_msj_error;
                PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                return;
             end if;
           exception
             when others then
               p_cod_error := 9;
               p_error     := 'Error al verificar cuenta 2' || SQLERRM;  
               return;
           end; 
           
           if not ( ( rg_cre.cod_modulo in ( 3, 4 ) and rg_cre.cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39,334 ) ) or
                        rg_cre.cod_modulo = 5 ) --Para MT recibido la Cuenta de Crédito puede ser la de Tarjetas
           then
              p_cod_error := 10;
              p_error := 'Modalidad de la cuenta no permite este tipo de operación';
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return;
           end if; 
           --Ya que es pago a proveedores
           v_tra_credito := 7196;
           
           rg_cre := pag_cta.g_ctas;
           
         end if;
       exception
         WHEN OTHERS THEN
           p_cod_error := 8;
           p_error     := 'bloque 3 ' || SQLERRM;  
           PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
           return; 
       end;
       
       begin
         if pas_snp.g_cod_error = 0 then
          -- Intentando Registrar la Operación para la Cta. (D).
          if rg_deb.cod_moneda <> rg_cre.cod_moneda then
             begin
             pas_snp.pr_obt_con_cambio( v_nro_con_cambio,
                                           'S',
                                           rg_deb.nro_cuenta,    -- Cta. de Débito
                                           rg_cre.nro_cuenta,    -- Cta. de Crédito
                                           rg_msj_mov_tra.monto, -- Monto de la Operación.
                                           rg_deb.cod_moneda,
                                           rg_cre.cod_moneda,
                                           v_cot_destino,
                                           v_mto_debito,
                                           v_mto_credito
                                          );   
              if pas_snp.fu_obt_cod_error <> 0 then
                  p_cod_error := 12;
                  p_error     := 'fu_obt_cod_error: '|| pas_snp.fu_obt_cod_error|| ' - pas_snp.pr_obt_con_cambio ' ||pas_snp.fu_obt_msj_error ;  
                  PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                  return;  
              end if;
            exception         
              WHEN OTHERS THEN
              p_cod_error := 13;
              p_error     := 'Error en pas_snp.pr_obt_con_cambio ' || SQLERRM;  
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return; 
            end;
            
            begin
              -- Para conversión de monedas. Detectar si el MT es  ENVIADO.
                
                   --Es un MT ENVIADO.
                   v_mon_origen  := rg_cre.cod_moneda;
                   v_mon_destino := rg_deb.cod_moneda;
                
            exception         
              WHEN OTHERS THEN
              p_cod_error := 14;
              p_error     := 'Error en conversión de moneda 1 ' || SQLERRM;  
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return; 
            end;
            
            begin
              if v_mto_credito is null then
                   pas_snp.pr_con_mon_a_moneda( v_mon_origen,
                                                v_mon_destino,
                                                nvl( rg_msj_mov_tra.monto, 0 ),
                                                v_mto_destino,
                                                v_cot_origen,
                                                v_cot_destino
                                              );
                end if;
                --
                if pas_snp.fu_obt_cod_error <> 0 then
                  p_cod_error := 15;
                  p_error     := 'fu_obt_cod_error: '|| pas_snp.fu_obt_cod_error|| ' - pas_snp.pr_con_mon_a_moned ' ||pas_snp.fu_obt_msj_error ;  
                  PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                  return;
                end if;
            exception         
              WHEN OTHERS THEN
              p_cod_error := 16;
              p_error     := 'Error en pas_snp.pr_con_mon_a_moneda ' || SQLERRM;  
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return;  
            end;
            
            begin
             
                 --Es un MT ENVIADO.
                 v_mto_debito  := v_mto_destino;
                 v_mto_credito := nvl( rg_msj_mov_tra.monto, 0 );
               
            EXCEPTION 
            WHEN OTHERS THEN
              p_cod_error := 17;
              p_error     := 'Error en conversión de moneda 2 ' || SQLERRM;  
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return; 
            end;
            
            
            
          else
            begin
            v_cotizacion  := null;
            v_mto_debito  := nvl( rg_msj_mov_tra.monto, 0 );
            v_mto_credito := nvl( rg_msj_mov_tra.monto, 0 ); 
            exception
              when others then
                p_cod_error := 18;
                p_error     := 'Error 1 ' || SQLERRM;  
                PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                return;
            end;
          end if; 
          
          begin
            if rg_deb.cod_moneda <> v_cod_mon_local then
                if rg_cre.cod_moneda = v_cod_mon_local then
                   v_mto_equ_local := v_mto_credito;
                else
                   v_mto_equ_local := null ;
                end if ;

                if nvl( v_cot_origen,1 ) = 1 then
                   v_cotizacion := v_cot_destino;
                else
                   v_cotizacion := v_cot_origen;
                end if;
             end if;
          exception
            when others then
              p_cod_error := 19;
              p_error     := 'Error 2 ' || SQLERRM; 
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null); 
              return;
          end;
          
          begin
            -- Si la cuenta es de la modalidad 455, setear valores del campo referencia cod_rubro y tip_mov_rubro
             pag_cta.pr_set_referencia ( NULL );

             -- Para los movimientos de Transferencias se debe colocar en el campo NRO_DOCUMENTO2
             -- El Tipo de Mensajería, Tipo de Operación y Sub Tipo de Operación
             -- Esta asignación sirve para recuperar la mensajería desde la consulta de movimientos
             v_nro_documento2 := rg_msj_mov_tra.cod_msj_swift ||
                                 rg_msj_mov_tra.cod_tip_operacion ||
                                 rg_msj_mov_tra.cod_sub_tip_operacion;
             pag_cta.pr_set_nro_documento2 ( v_nro_documento2 );
          exception
            when others then
              p_cod_error := 20;
              p_error     := 'Error al setear variables Deb. 1 ' || SQLERRM; 
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null); 
              return;
          end;
          
          begin
             -- Recupera el tipo de movimiento de la transacción
             v_tip_mov_debito := pas_snp.fu_obt_tip_mov_transaccion( rg_deb.cod_modulo,
                                                                     rg_deb.cod_modalidad,
                                                                     v_tra_debito
                                                                   );

             if pas_snp.fu_obt_cod_error <> 0 then
                p_cod_error := 21;
                p_error     := 'Error al recuperar tip. mov. 1';  
                PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                return;
             end if;
          
          exception
            when others then
              p_cod_error := 22;
              p_error     := 'Error al recuperar tip. mov. 2 ' || SQLERRM; 
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null); 
              return;
          end;
          
          
          begin
            if rg_deb.cod_modalidad = pas_snp.fu_obt_cod_mad_padre then
                --Setea las variables de COD_RUBRO, TIP_MOV_RUBRO
                pag_cta.pr_set_cod_rubro( pac_che.fu_obt_rub_cta_ban( rg_deb.nro_cuenta ), v_tip_mov_debito );

                --Setea el campo REFERENCIA del movimiento
                pag_cta.pr_set_referencia ( v_swi_participante );
             end if;
          exception
            when others then
              p_cod_error := 23;
              p_error     := 'Error al setear variables Deb. 2  ' || SQLERRM; 
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null); 
              return;
          end;
          
          
          begin
            v_cod_usuario := fu_obt_mov_user('PAYMPV');
            if p_cod_error <> 0 then
              return;
            end if;
            v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);
          exception
          when others then
              p_cod_error := 24;
              p_error     := 'Error al buscar usuario  ' || SQLERRM;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);  
              return;  
          end;
          
          begin
            v_hora := fu_obt_hora(v_cod_usuario);
            if p_cod_error <> 0 then
              return;
            end if;
          exception
          when others then
              p_cod_error := 25;
              p_error     := 'Error al buscar la hora  ' || SQLERRM;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);  
              return;  
          end;
          
          begin
            pag_cta.PR_SET_VARIABLES(p_cod_usuario    => v_cod_usuario,
                                     p_fec_valor      => rg_msj_mov_tra.fec_valor,
                                     p_cod_tra_padre  => v_tra_padre,
                                     p_estado         => 'N',
                                     p_reversado      => 'N',
                                     p_nro_secuencia  => v_nro_secuencia,
                                     p_est_cuenta     => null,
                                     p_cod_ofi_origen => v_cod_ofi_origen,
                                     p_cod_mod_padre  => v_mod_padre,
                                     p_cod_mad_padre  => v_mad_padre);
                                     
            pag_cta.pr_act_operacion( rg_deb.nro_cuenta,              -- Nro.Cta.
                                       v_hora,                         -- Hora
                                       v_tip_mov_debito,               -- Tip.Mov.
                                       rg_deb.cod_moneda,              -- Cod.Mon.
                                       v_mto_debito,                   -- Monto
                                       v_tra_padre,                    -- Trx.Padre
                                       v_tra_debito,                   -- Trx.Hija
                                       rg_msj_mov_tra.nro_referencia,  -- Nro.Doc.
                                       v_cotizacion,                   -- Cotizacion
                                       fug_obt_ofi_usuario (user),     -- Ofic.Orig.
                                       v_mod_padre,                    -- Mod.Pad.Cliente
                                       v_mad_padre,                    -- Mad.Pad.Cliente
                                       NULL,                           -- Cod.Tasa
                                       NULL,                           -- Val.Tasa
                                       v_concepto,                     -- Concepto
                                       'S',                            -- Emit.Aviso
                                       v_nro_secuencia,
                                       rg_msj_mov_tra.fec_valor,
                                       NULL,
                                       NULL,
                                       v_mto_equ_local
                                     );
                                     
                                    
            if pag_cta.fu_obt_cod_error <> 0 then
                p_cod_error := 26;
                p_error     :=  'Error pag_Cta ' ||  pag_cta.fu_obt_cod_error||' pag_cta.pr_act_operacion 1  ' || pag_cta.fu_obt_msj_error;
                PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);  
                return;
            end if;
          exception
            when others then
                p_cod_error := 27;  
                p_error := 'Error en pag_cta.pr_act_operacion 1 ' ||sqlerrm;
                PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                return; 
          end;
         end if;
       exception
         WHEN OTHERS THEN
           p_cod_error := 11;
           p_error     := 'bloque 4 ' || SQLERRM; 
           PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null); 
           return; 
       end;
       
       begin
        if pas_snp.fu_obt_cod_error = 0 then
          --Intentando Registrar la Operación para la Cta. (C).
          begin
            if rg_cre.cod_moneda <> v_cod_mon_local then
                if rg_deb.cod_moneda = v_cod_mon_local then
                   v_mto_equ_local := v_mto_debito;
                else
                   v_mto_equ_local := null ;
                end if ;
                if nvl( v_cot_origen,1 ) = 1 then
                   v_cotizacion := v_cot_destino;
                else
                   v_cotizacion := v_cot_origen;
                end if;
             end if;
          exception
            when others then
              p_cod_error := 29;  
              p_error := 'Error en conversion de moneda 5 ' ||sqlerrm;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return; 
          end;
          
          begin
            pag_cta.pr_set_referencia ( NULL );
          exception
            when others then
               p_cod_error := 30;  
               p_error := 'Error en setear referencia 5 ' ||sqlerrm;
               PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
               return; 
          end;
          
          begin
            -- Recupera el tipo de movimiento de la transacción
             v_tip_mov_credito := pas_snp.fu_obt_tip_mov_transaccion( rg_cre.cod_modulo,
                                                                      rg_cre.cod_modalidad,
                                                                      v_tra_credito
                                                                    );

             if pas_snp.fu_obt_cod_error <> 0 then
                 p_cod_error := 31;  
                 p_error := 'Error al recuperar tip. mov.';
                 PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
                 return;
             end if;
          exception
            when others then  
              p_cod_error := 32;  
              p_error := 'Error en pas_snp.fu_obt_tip_mov_transaccion 5 ' ||sqlerrm;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return;   
          end;
          
          begin
            if rg_cre.cod_modalidad = pas_snp.fu_obt_cod_mad_padre then
                --Setea las variables de COD_RUBRO, TIP_MOV_RUBRO
                pag_cta.pr_set_cod_rubro( pac_che.fu_obt_rub_cta_ban( rg_cre.nro_cuenta ), v_tip_mov_credito );

                --Setea el campo REFERENCIA del movimiento
                pag_cta.pr_set_referencia ( v_swi_participante );
             end if;
          exception
            when others then  
              p_cod_error := 33;  
              p_error := 'Error en pas_snp.fu_obt_tip_mov_transaccion 5 ' ||sqlerrm;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return; 
          end;
          
          begin
            if rg_cre.cod_modulo in ( 3, 4 ) and
               rg_cre.cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39,334 ) then
               --ENVIADO
              --Generar el movimiento
              rg_movi.cod_usuario     := v_cod_usuario;
              rg_movi.hora            := v_hora;
              rg_movi.fecha           := pag_cal.fu_obt_fec_actual( rg_cre.cod_modulo );
              -- Aumento la secuencia
              v_nro_secuencia         := v_nro_secuencia + 1;
              rg_movi.nro_secuencia   := v_nro_secuencia;
              rg_movi.cod_tra_padre   := v_tra_padre;
              rg_movi.cod_mod_padre   := v_mod_padre;
              rg_movi.cod_mad_padre   := v_mad_padre;
              rg_movi.cod_transaccion := v_tra_credito;
              rg_movi.cod_modulo      := rg_cre.cod_modulo;
              rg_movi.cod_modalidad   := rg_cre.cod_modalidad;
              rg_movi.cod_oficina     := rg_cre.cod_oficina;
              rg_movi.cod_moneda      := rg_cre.cod_moneda;
              rg_movi.fec_valor       := rg_msj_mov_tra.fec_valor;
              rg_movi.monto           := v_mto_credito;
              rg_movi.nro_documento   := rg_msj_mov_tra.nro_referencia;
              rg_movi.nro_documento2  := v_nro_documento2;
              rg_movi.nro_cuenta      := v_nro_cta_credito;
              rg_movi.cod_ofi_origen  := fug_obt_ofi_usuario (user);
              rg_movi.concepto        := v_concepto;
              rg_movi.emi_aviso       := 'N';
              rg_movi.estado          := 'N';
              rg_movi.reversado       := 'N';
              rg_movi.cotizacion      := v_cotizacion;
              rg_movi.mto_equ_local   := v_mto_equ_local;
              
              pag_gen.pr_ins_ge_movimiento( rg_movi );
              --Limpio variables cargadas para que no quede basura
              pag_cta.pr_set_cod_rubro(null, null); 
              
              -- Si no hubo errores cargar datos del movimiento para luego actualizarlos en GE_SNP_TRANSFERENCIAS.
              rg_msj_mov_tra.fecha         := pag_cal.fu_obt_fec_actual ( rg_cre.cod_modulo );
              rg_msj_mov_tra.hora          := v_hora;
              rg_msj_mov_tra.cod_usuario   := nvl(v_cod_usuario,user);
              rg_msj_mov_tra.nro_operacion := rg_msj_mov_tra.nro_referencia;
                
            end if;  
          exception
            when others then
              p_cod_error := 34;  
              p_error := 'Error al insertar credito ' ||sqlerrm;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return;
          end;
          
          begin
             v_nro_documento2 := NULL;
             pag_cta.pr_set_nro_documento2 ( v_nro_documento2 ); 
          exception
            when others then
              p_cod_error := 35;  
              p_error := 'Error en  pag_cta.pr_set_nro_documento2 ' || sqlerrm;
              PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);
              return;   
          end;
          
          
          
        end if; 
       exception
         WHEN OTHERS THEN
           p_cod_error := 28;
           p_error     := 'bloque 5 ' || SQLERRM;
           PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);  
           return;   
       end;
       
       
   end if;
 EXCEPTION
  WHEN OTHERS THEN
    p_cod_error := 2;
    p_error     := 'Error en lp_reg_mov_transferencia_prv ' || SQLERRM;
    PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null);   
    return;
 end lp_reg_mov_transferencia_prv;
 
BEGIN
  --incializamos
  p_cod_error := 0;
  p_error     := 'OK';
  
    IF rg_msj_mov_tra.cod_msj_swift IN (103,102,8, 4) THEN
      lp_reg_mov_transferencia_prv;
    END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    p_cod_error := 1;
    p_error     := 'Error en pr_pro_transferencia_prv ' || SQLERRM;
    PRG_INS_LOG_PROGRAMAS(p_cod_programa => 'PAG_PRV.PR_PRO_TRANSFERENCIA_PRV',
                           p_det_error    => fu_generarBitacora('S',p_cod_error, p_error ),
                           p_cod_persona  => p_cod_empresa,
                           p_nro_cuenta   => null); 
    return;
END pr_pro_transferencia_prv;


END PAG_PRV;
/
