CREATE OR REPLACE FUNCTION IT.fug_gen_jso_seprelad(p_fec_ini IN DATE, p_fec_fin IN DATE)
  RETURN clob IS
    v_respuesta        clob;
    v_result           clob;
    v_step             NUMBER := 12000; -- multiplo de 3
  --v_max              NUMBER(18) := 4000; -- Tamaño Máximo raw
    v_tot              NUMBER(18);
    v_ult              number := 1;
    v_can_depositos    number := 0;
    v_can_extracciones number := 0;
    v_can_cambios      NUMBER := 0;
    v_raw_aux          RAW(32767);
    v_can_transferencias number := 0;
    v_can_cancelaciones number := 0;
    v_arc_encriptado varchar2(1) := fug_obt_pardinamico('ARC_SEPRELAD_ENCRIPTADO');
    CURSOR c_depositos IS


         SELECT dep.nro_orden                        nro_orden ,
                dep.cod_oficina                      cod_oficina ,
                TO_CHAR(dep.fec_operacion, 'dd-MM-yyyy HH:mm:ss') fec_operacion,
                dep.nro_comprobante                  nro_comprobante ,
                dep.nom_completo                     nom_completo,
                dep.nro_documento                    nro_documento ,
                dep.cod_moneda                       cod_moneda ,
                dep.monto                            monto ,
                dep.nro_cuenta                       nro_cuenta ,
                dep.nro_documento                    nro_doc_beneficiario ,
                dep.tip_doc_depositante              tip_doc_depositante ,
                dep.nom_beneficiario                 nom_beneficiario,
                dep.tip_doc_beneficiario             tip_doc_beneficiario ,
                dep.cod_instrumento                  cod_instrumento ,
                dep.cotizacion                       cotizacion,
                dep.sal_cuenta                       sal_cuenta
         FROM ge_sep_depositos dep
         WHERE fec_operacion between p_fec_ini and p_fec_fin
         ORDER BY fec_operacion ASC;

    TYPE cursor1_type IS TABLE of c_depositos%rowtype;
    regd cursor1_type;
	---
    CURSOR c_extracciones IS
         SELECT ext.nro_orden                          nro_orden ,
                ext.cod_oficina                        cod_oficina ,
                TO_CHAR(ext.fec_operacion, 'dd-MM-yyyy HH:mm:ss') fec_operacion ,
                ext.nro_comprobante                    nro_comprobante,
                ext.nom_completo                       nom_completo,
                ext.nro_documento                      nro_documento ,
                ext.cod_moneda                         cod_moneda ,
                ext.monto                              monto ,
                ext.nro_cuenta                         nro_cuenta ,
                ext.nro_doc_beneficiario               nro_doc_beneficiario ,
                ext.nom_beneficiario                   nom_beneficiario,
                ext.tip_documento                      tip_documento ,
                ext.tip_doc_beneficiario               tip_doc_beneficiario ,
                ext.cod_instrumento                    cod_instrumento ,
                ext.cotizacion                         cotizacion,
                ext.sal_cuenta                         sal_cuenta
         FROM ge_sep_extracciones ext
          WHERE fec_operacion between p_fec_ini and p_fec_fin
         ORDER BY fec_operacion ASC;

    TYPE cursor2_type IS TABLE of c_extracciones%rowtype;
    rege cursor2_type;

    CURSOR c_cambios IS
      SELECT a.nro_orden                    nro_orden,            --item
             TO_CHAR(a.fec_operacion, 'dd-MM-yyyy HH24:MI:SS') fec_operacion, --fechaOperacion
             a.cod_oficina                  cod_oficina,          --sucursal
             a.nro_comprobante              nro_comprobante,      --numeroComprobante
             a.cod_instrumento              cod_instrumento,      --codInstrumento
             a.nom_completo                 nom_completo,         --nombreRazonSocial
             a.nro_documento                nro_documento,        --numeroDocumento
             a.cod_moneda                   cod_moneda,           --monedaOperacion
             a.monto                        monto,                --monto
             a.cotizacion                   cotizacion,           --cotizacion
             a.mto_equ_gs                   mto_equ_gs,           --montoOperacionGs
             a.nro_doc_beneficiario         nro_doc_beneficiario, --numeroDocumentoBenficiario
             a.nom_beneficiario             nom_beneficiario,     --nombreBeneficiario
             a.nro_cuenta                   nro_cuenta,           --numeroCuenta
             a.nro_cheque                   nro_cheque,           --numeroCheque
             a.bco_emisor                   bco_emisor,           --bancoEmisor
             a.tip_documento                tip_documento,        --tipoDocumento
             a.tip_doc_beneficiario         tip_doc_beneficiario  --tipoDocumentoBen
        FROM ge_sep_operaciones a
       WHERE a.cod_instrumento IN ('CAMCANJ','CAMARBITCO','CAMARBITVE','CAMCOMP','CAMVENT','FORWARD')
         AND TRUNC(fec_operacion) BETWEEN p_fec_ini AND p_fec_fin
       ORDER BY fec_operacion ASC;

    CURSOR c_transferencias IS
      SELECT a.nro_orden                    nro_orden,            --item
             TO_CHAR(a.fec_operacion, 'dd-MM-yyyy HH24:MI:SS') fec_operacion, --fechaOperacion
             a.cod_oficina                  cod_oficina,          --sucursal
             a.nro_comprobante              nro_comprobante,      --numeroComprobante
             a.cod_instrumento              cod_instrumento,      --codInstrumento
             nvl(REPLACE(replace(replace(replace(translate(a.nom_completo,
            'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
            'AEIOUYAEIOUAEIOUNN'),chr(10),''),chr(13),''),'"',''),chr(9),''),'nombreRazonSocial')nom_completo,--nombreRazonSocial
             a.nro_documento                nro_documento,        --numeroDocumento
             a.cod_moneda                   cod_moneda,           --monedaOperacion
             a.monto                        monto,                --monto
             a.cotizacion                   cotizacion,           --cotizacion
             a.mto_equ_gs                   mto_equ_gs,           --montoOperacionGs
             a.nro_doc_beneficiario         nro_doc_beneficiario, --numeroDocumentoBenficiario            
             nvl(REPLACE(replace(replace(replace(translate(a.nom_beneficiario,
            'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
            'AEIOUYAEIOUAEIOUNN'),chr(10),''),chr(13),''),'"',''),chr(9),''),'nombreBeneficiario')nom_beneficiario,--nombreBeneficiario
             a.nro_cuenta                   nro_cuenta,           --numeroCuenta
             a.tip_documento                tip_documento,        --tipoDocumento
             a.tip_doc_beneficiario         tip_doc_beneficiario, --tipoDocumentoBen
             nvl(REPLACE(replace(replace(replace(translate(a.swift,
            'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
            'AEIOUYAEIOUAEIOUNN'),chr(10),''),chr(13),''),'"',''),chr(9),''),'AAA') swift,                --swift
             nvl(a.nro_cta_otr_entidad,000) numeroCuentaOtraEntidad,--numeroCuentaOtraEntidad
             nvl(REPLACE(replace(replace(replace(translate(a.swi_beneficiario,
            'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
            'AEIOUYAEIOUAEIOUNN'),chr(10),''),chr(13),''),'"',''),chr(9),''),'AAA') swiftBeneficiario,    --swiftBeneficiario
             a.ciudad                       ciudad,               --ciudad
             nvl(LTRIM(REPLACE(REPLACE(replace(translate(UPPER(a.motivo),
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN'),chr(10),''),chr(9),''),chr(13),'')),'Motivo')  motivo,    --motivo
             nvl(a.pai_ent_internacional,'PRY') paisEntidadInternacional,
             a.ent_origen                   entidadOrigen,        --entidadOrigen
             a.ent_destino                  entidadDestino        --entidadDestino
        FROM ge_sep_operaciones a
       WHERE a.cod_instrumento in ('TRANACREC','TRANACREM','TRAEXTREC','TRAEXTREM','TRAINTER')
         AND TRUNC(fec_operacion) BETWEEN p_fec_ini AND p_fec_fin
       ORDER BY fec_operacion ASC;


    CURSOR c_cancelaciones IS
      SELECT a.nro_orden                    nro_orden,            --item
             TO_CHAR(a.fec_operacion, 'dd-MM-yyyy HH24:MI:SS') fec_operacion, --fechaOperacion 
             a.cod_oficina                  cod_oficina,          --sucursal
             a.nro_comprobante              nro_comprobante,      --numeroComprobante
             a.cod_instrumento              cod_instrumento,      --codInstrumento
             REPLACE(replace(replace(replace(a.nom_completo ,chr(10),''),chr(13),''),'"',''),chr(9),'') nom_completo,         --nombreRazonSocial
             a.nro_documento                nro_documento,        --numeroDocumento
             a.cod_moneda                   cod_moneda,           --monedaOperacion
             a.monto                        monto,                --monto
             a.cotizacion                   cotizacion,           --cotizacion
             a.mto_equ_gs                   mto_equ_gs,           --montoOperacionGs
             a.nro_cuenta                   nro_cuenta,           --numeroCuenta
             a.tip_documento                tip_documento        --tipoDocumento
        FROM ge_sep_operaciones a
       WHERE a.cod_instrumento in ('CANAPREDC', 'CANANCREF')
         AND TRUNC(fec_operacion) BETWEEN p_fec_ini AND p_fec_fin
       ORDER BY fec_operacion ASC;

    TYPE cursor3_type IS TABLE of c_cambios%rowtype;
    regc cursor3_type;

     TYPE cursor4_type IS TABLE of c_transferencias%rowtype;
    regt cursor4_type;

     TYPE cursor5_type IS TABLE of c_cancelaciones%rowtype;
    regcan cursor5_type;
  begin
    pre_cam_for_numerico('.,');

    DBMS_LOB.CREATETEMPORARY(v_result,false);
    DBMS_LOB.OPEN(v_result, DBMS_LOB.LOB_READWRITE);
    --apertura estructura general
    DBMS_LOB.append(v_result,'{'||chr(10));

    --La cabecera lo ponemos al final

    --data
    DBMS_LOB.append(v_result,'"data":'|| '{' ||chr(10));

    --Deposito
    DBMS_LOB.append(v_result,'"listaDeposito": ' || '['||chr(10));

    OPEN c_depositos;
    LOOP
      FETCH c_depositos BULK COLLECT INTO regd LIMIT 5000;
      FOR i in 1.. regd.count LOOP
        BEGIN

        v_can_depositos := v_can_depositos +1;
        DBMS_LOB.append(v_result,'{'||chr(10));
            DBMS_LOB.append(v_result,'"item":'||substr(regd(i).nro_orden,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"sucursal":'||'"'||substr(regd(i).cod_oficina,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"fechaOperacion":'||'"'||substr(regd(i).fec_operacion,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroComprobante":'||'"'||substr(regd(i).nro_comprobante,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreRazonSocial":'||'"'||substr(regd(i).nom_completo,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumento":'||'"'||substr(regd(i).nro_documento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monedaOperacion":'||'"'||substr(regd(i).cod_moneda,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monto":'|| substr(regd(i).monto,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroCuenta":'||'"'||substr(regd(i).nro_cuenta,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumentoBeneficiario":'||'"'||substr(regd(i).nro_doc_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreBeneficiario":'||'"'||substr(regd(i).nom_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumentoDep":'||'"'||substr(regd(i).tip_doc_depositante,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumentoBen":'||'"'||substr(regd(i).tip_doc_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"codInstrumento":'||'"'||substr(regd(i).cod_instrumento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"cotizacion":'||substr(regd(i).cotizacion,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"saldoCuenta":'||substr(regd(i).sal_cuenta,1,200)||chr(10));
        DBMS_LOB.append(v_result,'},');

         END;
      END LOOP;
      EXIT WHEN c_depositos%NOTFOUND;
    END LOOP;

    dbms_lob.erase(v_result, v_ult, dbms_lob.getlength(v_result)); --borramos la ultima coma
    DBMS_LOB.append(v_result,'],'||chr(10));

     --Extraccion
    DBMS_LOB.append(v_result,'"listaExtraccion": ' || '['||chr(10));

    OPEN c_extracciones;
    LOOP
      FETCH c_extracciones BULK COLLECT INTO rege LIMIT 5000;
      FOR i in 1.. rege.count LOOP
         BEGIN

        v_can_extracciones := v_can_extracciones +1;
        DBMS_LOB.append(v_result,'{'||chr(10));
            DBMS_LOB.append(v_result,'"item":'||substr(rege(i).nro_orden,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"sucursal":'||'"'||substr(rege(i).cod_oficina,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"fechaOperacion":'||'"'||substr(rege(i).fec_operacion,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroComprobante":'||'"'||substr(rege(i).nro_comprobante,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreRazonSocial":'||'"'||substr(rege(i).nom_completo,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumento":'||'"'||substr(rege(i).nro_documento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monedaOperacion":'||'"'||substr(rege(i).cod_moneda,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monto":'|| substr(rege(i).monto,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroCuenta":'||'"'||substr(rege(i).nro_cuenta,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumentoBeneficiario":'||'"'||substr(rege(i).nro_doc_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreBeneficiario":'||'"'||substr(rege(i).nom_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumento":'||'"'||substr(rege(i).tip_documento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumentoBen":'||'"'||substr(rege(i).tip_doc_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"codInstrumento":'||'"'||substr(rege(i).cod_instrumento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"cotizacion":'||substr(rege(i).cotizacion,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"saldoCuenta":'||substr(rege(i).sal_cuenta,1,200)||chr(10));
        DBMS_LOB.append(v_result,'},');

         END;
      END LOOP;
      EXIT WHEN c_extracciones%NOTFOUND;
    END LOOP;

    v_ult := 1;
    dbms_lob.erase(v_result, v_ult, dbms_lob.getlength(v_result)); -- borra la última coma
    DBMS_LOB.append(v_result,'],'||chr(10));

    --Transferencia
    DBMS_LOB.append(v_result,'"listaTransferencia": ' || '['||chr(10));
    OPEN c_transferencias;
    LOOP
      FETCH c_transferencias BULK COLLECT INTO regt LIMIT 5000;
      FOR i IN 1..regt.count LOOP
        BEGIN
          v_can_transferencias := v_can_transferencias + 1;
          DBMS_LOB.append(v_result,'{'||chr(10));
            DBMS_LOB.append(v_result,'"item":'||substr(regt(i).nro_orden,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"fechaOperacion":'||'"'||substr(regt(i).fec_operacion,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"sucursalOrigen":'||'"'||substr(regt(i).cod_oficina,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroComprobante":'||'"'||substr(regt(i).nro_comprobante,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreRazonSocial":'||'"'||substr(regt(i).nom_completo,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumento":'||'"'||substr(regt(i).nro_documento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroCuenta":'||'"'||substr(regt(i).nro_cuenta,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"swift":'||'"'||substr(regt(i).swift,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monedaOperacion":'||'"'||substr(regt(i).cod_moneda,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monto":'||substr(regt(i).monto,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"montoOperacionEnGs":'||substr(regt(i).mto_equ_gs,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"cotizacion":'||substr(regt(i).cotizacion,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumentoBeneficiario":'||'"'||substr(regt(i).nro_doc_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreBeneficiario":'||'"'||substr(regt(i).nom_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroCuentaOtraEntidad":'||'"'||substr(regt(i).numeroCuentaOtraEntidad,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumento":'||'"'||substr(regt(i).tip_documento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumentoBen":'||'"'||substr(regt(i).tip_doc_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"codInstrumento":'||'"'||substr(regt(i).cod_instrumento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"swiftBeneficiario":'||'"'||substr(regt(i).swiftBeneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"ciudad":'||'"'||substr(regt(i).ciudad,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"motivo":'||'"'||substr(regt(i).motivo,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"paisEntidadInternacional":'||'"'||substr(regt(i).paisEntidadInternacional,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"entidadOrigen":'||'"'||substr(regt(i).entidadOrigen,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"entidadDestino":'||'"'||substr(regt(i).entidadDestino,1,200)||'"'||chr(10));
          DBMS_LOB.append(v_result,'},');
        END;
      END LOOP;
      EXIT WHEN c_transferencias%NOTFOUND;
    END LOOP;

    v_ult := 1;
    dbms_lob.erase(v_result, v_ult, dbms_lob.getlength(v_result)); -- borra la última coma
    DBMS_LOB.append(v_result,'],'||chr(10));

    --Cambios
    DBMS_LOB.append(v_result,'"listaCambio": ' || '['||chr(10));
    --Por ahora vacio
    OPEN c_cambios;
    LOOP
      FETCH c_cambios BULK COLLECT INTO regc LIMIT 5000;
      FOR i IN 1..regc.count LOOP
        BEGIN
          v_can_cambios := v_can_cambios + 1;
          DBMS_LOB.append(v_result,'{'||chr(10));
            DBMS_LOB.append(v_result,'"item":'||substr(regc(i).nro_orden,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"sucursal":'||'"'||substr(regc(i).cod_oficina,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"fechaOperacion":'||'"'||substr(regc(i).fec_operacion,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroComprobante":'||'"'||substr(regc(i).nro_comprobante,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreRazonSocial":'||'"'||substr(regc(i).nom_completo,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumento":'||'"'||substr(regc(i).nro_documento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumento":'||'"'||substr(regc(i).tip_documento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monedaOperacion":'||'"'||substr(regc(i).cod_moneda,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monto":'||substr(regc(i).monto,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"cotizacion":'||substr(regc(i).cotizacion,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"montoOperacionGs":'||substr(regc(i).mto_equ_gs,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroCuenta":'||'"'||substr(regc(i).nro_cuenta,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumentoBeneficiario":'||'"'||substr(regc(i).nro_doc_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreBeneficiario":'||'"'||substr(regc(i).nom_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumentoBen":'||'"'||substr(regc(i).tip_doc_beneficiario,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroCheque":'||'"'||substr(regc(i).nro_cheque,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"codInstrumento":'||'"'||substr(regc(i).cod_instrumento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"bancoEmisor":'||'"'||substr(regc(i).bco_emisor,1,200)||'"'||chr(10));
          DBMS_LOB.append(v_result,'},');
        END;
      END LOOP;
      EXIT WHEN c_cambios%NOTFOUND;
    END LOOP;

    v_ult := 1;
    dbms_lob.erase(v_result, v_ult, dbms_lob.getlength(v_result)); -- borra la última coma
    DBMS_LOB.append(v_result,'],'||chr(10));

     --Cancelacion
    DBMS_LOB.append(v_result,'"listaCancelacion": ' || '['||chr(10));
    --Por ahora vacio
    OPEN c_cancelaciones;
    LOOP
      FETCH c_cancelaciones BULK COLLECT INTO regcan LIMIT 5000;
      FOR i IN 1..regcan.count LOOP
        BEGIN
          v_can_cancelaciones := v_can_cancelaciones + 1;
          DBMS_LOB.append(v_result,'{'||chr(10));
            DBMS_LOB.append(v_result,'"item":'||substr(regcan(i).nro_orden,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"fechaOperacion":'||'"'||substr(regcan(i).fec_operacion,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"sucursal":'||'"'||substr(regcan(i).cod_oficina,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroComprobante":'||'"'||substr(regcan(i).nro_comprobante,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreRazonSocialDeudor":'||'"'||substr(regcan(i).nom_completo,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumentoDeudor":'||'"'||substr(regcan(i).nro_documento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monedaOperacion":'||'"'||substr(regcan(i).cod_moneda,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"monto":'||substr(regcan(i).monto,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"cotizacion":'||substr(regcan(i).cotizacion,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"montoOperacionEnGs":'||substr(regcan(i).mto_equ_gs,1,200)||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroDocumentoAutorizado":'||'"'||null||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"nombreAutorizado":'||'"'||null||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumentoDeu":'||'"'||substr(regcan(i).tip_documento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"tipoDocumentoAut":'||'"'||null||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"codInstrumento":'||'"'||substr(regcan(i).cod_instrumento,1,200)||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"motivo":'||'"'||null||'"'||','||chr(10));
            DBMS_LOB.append(v_result,'"numeroCredito":'||'"'||substr(regcan(i).nro_cuenta,1,200)||'"'||chr(10));

          DBMS_LOB.append(v_result,'},');
        END;
      END LOOP;
      EXIT WHEN c_cancelaciones%NOTFOUND;
    END LOOP;

    v_ult := 1;
    dbms_lob.erase(v_result, v_ult, dbms_lob.getlength(v_result)); -- borra la última coma
    DBMS_LOB.append(v_result,']'||chr(10));

    --cierre Data
    DBMS_LOB.append(v_result,'}');

    DBMS_LOB.append(v_result,','||chr(10));

    --Cabecera
    DBMS_LOB.append(v_result,'"cantidadRegDeposito":'|| v_can_depositos ||','||chr(10));
    DBMS_LOB.append(v_result,'"cantidadRegExtraccion":'|| v_can_extracciones || ','||chr(10));
    DBMS_LOB.append(v_result,'"cantidadRegTransferencia":'|| v_can_transferencias ||','||chr(10));
    DBMS_LOB.append(v_result,'"cantidadRegCambios":' || v_can_cambios ||','||chr(10));
    DBMS_LOB.append(v_result,'"cantidadRegCancelacion":'|| v_can_cancelaciones ||chr(10));

    --cierre general
    DBMS_LOB.append(v_result,'}');

    if nvl(v_arc_encriptado,'N') = 'S' then
       --conversion a Base64
       DBMS_LOB.CREATETEMPORARY(v_respuesta,false);
       DBMS_LOB.OPEN(v_respuesta, DBMS_LOB.LOB_READWRITE);
       
       v_tot := dbms_lob.getlength(v_result);
       
       -- IF v_tot > v_max THEN
       FOR i IN 0 .. trunc((v_tot - 1 ) / v_step) LOOP
           v_raw_aux := utl_raw.cast_to_raw(dbms_lob.substr(v_result,v_step, i * v_step + 1));
           v_raw_aux := utl_encode.base64_encode(v_raw_aux);
           DBMS_LOB.append(v_respuesta, utl_raw.cast_to_varchar2(v_raw_aux));
       END LOOP;
       ---END IF;

       return v_respuesta;
    else
       return v_result;--
    end if;
  EXCEPTION
    when others then
      raise_application_error(-20000,sqlerrm);
  END;
/

