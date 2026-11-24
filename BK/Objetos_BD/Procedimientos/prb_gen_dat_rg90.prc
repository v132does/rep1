create or replace procedure it.PRB_GEN_DAT_RG90 is
  v_error                varchar2(4000);
  v_tipo_identificador   number(3);
  v_cod_tipo_comprobante number;
  v_nro_comprobante      varchar2(20);
  V_MONTO_GRAVADO_10     number;
  V_MONTO_GRAVADO_5      number;
  V_MONTO_EXENTO         number;
  V_MONTO_TOTAL          number;
  v_condicion            varchar2(1);
  v_moneda_extranjera    varchar2(1);
  v_imputa_iva           varchar2(1);
  v_no_imputa            varchar2(1);
  v_nro_comprobante_ref  varchar2(20);
  v_timbrado             varchar2(10);
  V_FEC_ACTUAL           DATE;
  V_FEC_INI              DATE;
  V_FEC_FIN              DATE;
  --v_MEN_ERROR            varchar2(1000);
  --v_cod_tip_documento    ba_tip_documentos.cod_tip_documento%type;
  v_ruc_entidad          ba_personas.nro_documento%type;
  v_nom_entidad          ba_personas.nom_completo%type;
  v_tip_ide_ins          varchar2(100);
  v_doc_ins              varchar2(100);
  v_raz_ins              varchar2(200);
  v_ser_fac_aut          VARCHAR2(20);
  v_ser_fac_aut_ext      VARCHAR2(20);
  v_val_nro_identificacion VARCHAR2(1000);
  v_timbrado_actual      cb_par_comprobantes.nro_timbrado%type;
  V_TIPO_COMPROBANTE     CB_RG_90_TMP.COD_TIPO_COMPROBANTE%TYPE;
  V_COD_CONDICION            CB_RG_90_TMP.CONDICION%TYPE;     

  CURSOR C_INS_DAT IS

    SELECT '1' tipo_registro,
           FUE_OBT_VAL_MAX_REFCODES('RES_90_TIP_IDENTIFICACION',
                                    p.cod_tip_documento) tipo_identificador,
           C.NRO_DOCUMENTO NRO_IDENTIFICADOR,
           C.NOM_COMPLETO RAZ_SOCIAL,
           FUE_OBT_VAL_MAX_REFCODES('RES_90_TIP_COMPROBANTES', c.tip_comprobante) COD_TIPO_COMPROBANTE,
           C.FECHA FECHA_EMISION,
           C.NRO_TIMBRADO,
           C.NRO_FACTURA NRO_COMPROBANTE,
           C.Mto_Gravado_10_Gs + C.IMPUESTO_10_gs MONTO_GRAVADO_10,
           C.MTO_GRAVADO_5_gs + C.IMPUESTO_5_gs MONTO_GRAVADO_5,
           C.MTO_EXENTO_gs MTO_EXENTO,
           C.MTO_GRAVADO_10_gs + C.IMPUESTO_10_gs + C.MTO_GRAVADO_5_gs +
           C.IMPUESTO_5_gs + C.MTO_EXENTO_gs MONTO_TOTAL,
           DECODE(C.TIP_venta, 'CR', '2', '1') CONDICION,
           DECODE(MTO_GRAVADO_10_gs - MTO_GRAVADO_10, 0, 'N', 'S') MONEDA_EXTRANJERA,
           'S' IMPUTA_IVA,
           'N' IMPUTA_IRE,
           'N' IMPUTA_IRP_RSP,
           'N' NO_IMPUTA,
           C.NRO_FAC_REFERENCIA FACTURA_ASOCIADA,
           C.NRO_TIM_REFERENCIA TIMBRADO_ASOCIADO,
           c.cod_persona, c.tip_comprobante
      FROM cb_lib_ventas c, ba_personas p
     WHERE C.COD_PERSONA = P.COD_PERSONA
       AND c.fecha BETWEEN V_FEC_INI AND V_FEC_FIN
    UNION ALL
    --compras 1
    SELECT '2' tipo_registro,
           FUE_OBT_VAL_MAX_REFCODES('RES_90_TIP_IDENTIFICACION',
                                    p.cod_tip_documento) tipo_identificador,
           nvl(substr(C.NRO_DOCUMENTO, 1, instr(C.NRO_DOCUMENTO, '-') - 1),
               C.NRO_DOCUMENTO) NRO_IDENTIFICADOR,
           C.RAZ_SOCIAL,
           FUE_OBT_VAL_MAX_REFCODES('RES_90_TIP_COMPROBANTES', d.tip_comprobante) COD_TIPO_COMPROBANTE,

           C.FECHA FECHA_EMISION,
           C.NRO_TIMBRADO,
           C.NRO_FACTURA NRO_COMPROBANTE,
           round((C.MTO_GRAVADO_10 + C.IMPUESTO_10) *
             decode(d.cod_moneda,'GS',1,FUG_OBT_COTIZACION(d.cod_moneda,c.fecha)),0) MONTO_GRAVADO_10,
           round((C.MTO_GRAVADO_5 + C.IMPUESTO_5)*
             decode(d.cod_moneda,'GS',1,d.cotizacion),0) MONTO_GRAVADO_5,
           round(C.MTO_EXENTO * decode(d.cod_moneda,'GS',1,FUG_OBT_COTIZACION(d.cod_moneda,c.fecha)),0) monto_exento,
           round((C.MTO_GRAVADO_10 + C.IMPUESTO_10 + C.MTO_GRAVADO_5 +
           C.IMPUESTO_5 + C.MTO_EXENTO)*
             decode(d.cod_moneda,'GS',1,FUG_OBT_COTIZACION(d.cod_moneda,c.fecha)),0) MONTO_TOTAL,
           DECODE(C.TIPO, 'CR', '2', '1') CONDICION,
           decode(d.cod_moneda, 'GS', 'N', 'S') MONEDA_EXTRANJERA,
           'S' IMPUTA_IVA,
           'N' IMPUTA_IRE,
           'N' IMPUTA_IRP_RSP,
           'N' NO_IMPUTA,
           NULL FACTURA_ASOCIADA,
           NULL TIMBRADO_ASOCIADO,
           c.cod_persona, d.tip_comprobante
      From cb_lib_compras c, ba_personas p, cb_lib_compras_det d
     WHERE C.COD_PERSONA = P.COD_PERSONA
       and c.nro_factura = d.nro_factura
       and c.fecha = d.fecha
       and c.nro_timbrado = d.nro_timbrado
       and c.fecha BETWEEN V_FEC_INI AND V_FEC_FIN
    union all
    --compras 2
    SELECT '2' tipo_registro,
           FUE_OBT_VAL_MAX_REFCODES('RES_90_TIP_IDENTIFICACION',
                                    p.cod_tip_documento) tipo_identificador,
           nvl(substr(C.NRO_DOCUMENTO, 1, instr(C.NRO_DOCUMENTO, '-') - 1),
               C.NRO_DOCUMENTO) NRO_IDENTIFICADOR,
           C.RAZ_SOCIAL,
           FUE_OBT_VAL_MAX_REFCODES('RES_90_TIP_COMPROBANTES', d.tip_comprobante) COD_TIPO_COMPROBANTE,

           C.FECHA FECHA_EMISION,
           C.NRO_TIMBRADO,
           C.NRO_FACTURA NRO_COMPROBANTE,
           round((C.MTO_GRAVADO_10 + C.IMPUESTO_10) *
             decode(d.cod_moneda,'GS',1,FUG_OBT_COTIZACION(d.cod_moneda,c.fecha)),0) MONTO_GRAVADO_10,
           round((C.MTO_GRAVADO_5 + C.IMPUESTO_5)*
             decode(d.cod_moneda,'GS',1,FUG_OBT_COTIZACION(d.cod_moneda,c.fecha)),0) MONTO_GRAVADO_5,
           round(C.MTO_EXENTO * decode(d.cod_moneda,'GS',1,FUG_OBT_COTIZACION(d.cod_moneda,c.fecha)),0) monto_exento,
           round((C.MTO_GRAVADO_10 + C.IMPUESTO_10 + C.MTO_GRAVADO_5 +
           C.IMPUESTO_5 + C.MTO_EXENTO)*
             decode(d.cod_moneda,'GS',1,FUG_OBT_COTIZACION(d.cod_moneda,c.fecha)),0) MONTO_TOTAL,
           DECODE(C.TIPO, 'CR', '2', '1') CONDICION,
           decode(d.cod_moneda, 'GS', 'N', 'S') MONEDA_EXTRANJERA,
           'S' IMPUTA_IVA,
           'N' IMPUTA_IRE,
           'N' IMPUTA_IRP_RSP,
           'N' NO_IMPUTA,
           NULL FACTURA_ASOCIADA,
           NULL TIMBRADO_ASOCIADO,
           c.cod_persona, d.tip_comprobante
      From cb_lib_compras c, ba_personas p, pv_compras d

     WHERE C.COD_PERSONA = P.COD_PERSONA
       and C.FECHA = D.FECHA
       AND C.NRO_FACTURA = D.NRO_FACTURA
       AND C.NRO_TIMBRADO = D.TIMBRADO
       and instr(fug_obt_pardinamico('RES_90_COMP_EXCLUIR'), d.tip_emision) = 0
       and c.fecha BETWEEN V_FEC_INI AND V_FEC_FIN;
  -- cursor para generar detalle
  cursor detalle is
    Select d.rowid, d.*
      From it.CB_RG_90_TMP D
     order by TIPO_REGISTRO, fecha_emision, d.nro_comprobante;
  --procedure pr_val_tip_identificacion( p_tipo in varchar2, p_documento in varchar2, p_mensaje out varchar2);

  function fu_val_tip_identificacion( p_tipo in varchar2, p_documento in varchar2)
    return varchar2 IS
  V_NUM NUMBER;
  BEGIN
    IF p_tipo = '12' THEN--CI
      IF LENGTH(P_DOCUMENTO) BETWEEN 5 AND 8 THEN--
        BEGIN
          V_NUM := TO_NUMBER(P_DOCUMENTO);
          if length(P_DOCUMENTO) <> length(to_char(V_NUM)) then
             RETURN 'El numero de Cedula no corresponde al formato correcto, favor verifique.'||P_TIPO;
          end if;
        EXCEPTION
          WHEN OTHERS THEN
            BEGIN
              V_NUM:=TO_NUMBER(SUBSTR(P_DOCUMENTO,1,LENGTH(P_DOCUMENTO)-1));
              if (length(P_DOCUMENTO)-1) <> length(to_char(V_NUM)) then
                 RETURN 'El numero de Cedula no corresponde al formato correcto, favor verifique.'||P_TIPO;
              end if;
            EXCEPTION
              WHEN OTHERS THEN
                RETURN 'El numero de Cedula no corresponde al formato correcto, favor verifique.'||P_TIPO;
            END;
        END;
      else
         RETURN 'El numero de Cedula no corresponde al formato correcto, favor verifique.'||P_TIPO;
      END IF;
    elsif P_TIPO = '11' THEN--RUC
      IF LENGTH(P_DOCUMENTO) BETWEEN 5 AND 8 THEN--
        BEGIN
          V_NUM := TO_NUMBER(P_DOCUMENTO);
          if length(P_DOCUMENTO) <> length(to_char(V_NUM)) then
             RETURN 'El numero de RUC no corresponde al formato correcto, favor verifique.'||P_TIPO;
          end if;
        EXCEPTION
          WHEN OTHERS THEN
            BEGIN
              V_NUM:=TO_NUMBER(SUBSTR(P_DOCUMENTO,1,LENGTH(P_DOCUMENTO)-1));
              if (length(P_DOCUMENTO)-1) <> length(to_char(V_NUM)) then
                 RETURN 'El numero de RUC no corresponde al formato correcto, favor verifique.'||P_TIPO;
              end if;
            EXCEPTION
              WHEN OTHERS THEN
                RETURN 'El numero de RUC no corresponde al formato correcto, favor verifique.'||P_TIPO;
            END;
        END;
      else
        RETURN 'El numero de RUC no corresponde al formato correcto, favor verifique.'||P_TIPO;
      END IF;
    END IF;
    RETURN 'OK';
  END;


  --cursor para insertar en la tabla temporal--

BEGIN
  execute immediate 'truncate table cb_rg_90_tmp'; --TRUNCAR DATOS DE LA TABLA TEMPORAL
  V_FEC_ACTUAL := FUE_OBT_FEC_CALENDAR(1);
  --busca mes vencido
  SELECT TRUNC(ADD_MONTHS(V_FEC_ACTUAL, -1), 'MM'),
         LAST_DAY(ADD_MONTHS(V_FEC_ACTUAL, -1))
    INTO V_FEC_INI, V_FEC_FIN
    FROM DUAL;
  DELETE FROM CB_RG_90 WHERE PERIODO = TO_CHAR(V_FEC_INI, 'MM/YYYY');
  -- Recupera datos de la Entidad
   select nvl(substr(NRO_DOCUMENTO, 1, instr(NRO_DOCUMENTO, '-') - 1),
               NRO_DOCUMENTO)
          nro_documento, nom_completo
     into v_ruc_entidad, v_nom_entidad
     from ba_personas p, ge_par_generales g
    where g.cod_persona = p.cod_persona;
   v_ser_fac_aut := fug_obt_pardinamico('RES_90_SER_AUTOFAC');
   v_ser_fac_aut_ext := fug_obt_pardinamico('RES_90_SER_AUTOFAC_EXT');
  FOR D IN C_INS_DAT LOOP
    begin
       select p.nro_timbrado
       into   v_timbrado_actual
       from   cb_par_comprobantes p
       where  p.tipo = d.tip_comprobante
       and    p.fec_vencimiento = (select max(p2.fec_vencimiento)
                                   from   cb_par_comprobantes p2
                                   where  p2.tipo = p.tipo
                                   and    d.fecha_emision between  p2.fec_ini_timbrado and p2.fec_vencimiento);
    exception
      when others then
      raise_application_error(-20000,'Error al buscar timbrado del comprobante '||d.nro_comprobante);
    end;
    if v_timbrado_actual = d.nro_timbrado and v_ser_fac_aut =  substr(d.nro_comprobante,1,7) and d.tipo_registro = '2' then
         v_tip_ide_ins := '11';
         v_doc_ins     := v_ruc_entidad;
         v_raz_ins     := v_nom_entidad;
         V_TIPO_COMPROBANTE := D.COD_TIPO_COMPROBANTE;
    elsif v_timbrado_actual = d.nro_timbrado and v_ser_fac_aut_ext =  substr(d.nro_comprobante,1,7) and d.tipo_registro = '2' then
         v_tip_ide_ins := '17';
         v_doc_ins     := d.nro_identificador;
         v_raz_ins     := d.raz_social;
         V_TIPO_COMPROBANTE :='101';
    elsif d.tipo_registro = '1' and d.tipo_identificador = '18' then
         v_tip_ide_ins := '18';
         v_doc_ins     := '1';
         v_raz_ins     := 'CLIENTE DEL EXTERIOR';
         V_TIPO_COMPROBANTE :=D.COD_TIPO_COMPROBANTE;
    elsif d.tipo_registro = '2' and d.tipo_identificador = '18' then
         v_tip_ide_ins := '17';
         v_doc_ins     := d.nro_identificador;
         v_raz_ins     := d.raz_social;
         V_TIPO_COMPROBANTE :=D.COD_TIPO_COMPROBANTE;
    elsif d.tipo_identificador = '15' then
         v_tip_ide_ins := '15';
         v_doc_ins     := 'X';
         v_raz_ins     := d.raz_social;
         V_TIPO_COMPROBANTE :=D.COD_TIPO_COMPROBANTE;     
    else
         v_tip_ide_ins := d.tipo_identificador;
         v_doc_ins     := d.nro_identificador;
         v_raz_ins     := d.raz_social;
         V_TIPO_COMPROBANTE :=D.COD_TIPO_COMPROBANTE;
    end if;
    ---NC
    IF V_TIPO_COMPROBANTE = '110' AND D.TIPO_REGISTRO = '1' THEN
         v_tip_ide_ins := '11';
         v_doc_ins     := v_ruc_entidad;
         v_raz_ins     := v_nom_entidad;
         V_COD_CONDICION   := '1';
    ELSE
         V_COD_CONDICION := D.CONDICION;
    END IF;
    INSERT into CB_RG_90_TMP(tipo_registro,
						  cod_tip_documento,
						  nro_identificador,
						  raz_social,
						  cod_tipo_comprobante,
						  fecha_emision,
						  nro_timbrado,
						  nro_comprobante,
						  monto_gravado_10,
						  monto_gravado_5,
						  monto_exento,
						  monto_total,
						  condicion,
						  moneda_extranjera,
						  imputa_iva,
						  imputa_ire,
						  imputa_irp_rsp,
						  no_imputa,
						  factura_asociada,
						  timbrado_asociado,
						  procesado,
						  error,
						  usu_insercion,
						  fec_insercion)
    values
      (D.TIPO_REGISTRO,
       v_tip_ide_ins,--/*D.TIPO_IDENTIFICADOR*/,
       v_doc_ins,--D.NRO_IDENTIFICADOR,
       v_raz_ins,--D.RAZ_SOCIAL,
       V_TIPO_COMPROBANTE,
       D.FECHA_EMISION,
       D.NRO_TIMBRADO,
       D.NRO_COMPROBANTE,
       D.MONTO_GRAVADO_10,
       D.MONTO_GRAVADO_5,
       D.MTO_EXENTO,
       D.MONTO_TOTAL,
       V_COD_CONDICION,
       D.MONEDA_EXTRANJERA,
       D.IMPUTA_IVA,
       D.IMPUTA_IRE,
       D.IMPUTA_IRP_RSP,
       D.NO_IMPUTA,
       D.FACTURA_ASOCIADA,
       D.TIMBRADO_ASOCIADO,
       'N',
       NULL,
	   user,
	   sysdate);
  end loop;
  COMMIT; ---comitear
  for j in detalle loop

    v_error := null;
    --valida tipo_registro
    if j.tipo_registro is null then
      v_error := nvl(v_error, '') ||
                 '- No se enontró Tipo de Registro, favor verifique.';
    else
      --venta
      if j.tipo_registro = 1 then
        if j.cod_tip_documento is null then
          v_error := nvl(v_error, '') ||
                     '- No se enontró Tipo de Identificacion.';
        else
          begin
            v_tipo_identificador := j.cod_tip_documento;
          exception
            when others then
              v_error := nvl(v_error, '') ||
                         '- No se enontró Tipo de Identificacion válido.';
          end;
        end if;
        --valida nro_identificador
        if j.NRO_IDENTIFICADOR is null then
          v_error := nvl(v_error, '') ||
                     '- No se enontró Número de Documento.';
        else
          v_val_nro_identificacion :=  fu_val_tip_identificacion(v_tipo_identificador, j.NRO_IDENTIFICADOR);
          if v_val_nro_identificacion <> 'OK' THEN
             v_error := nvl(v_error, '')||
                     '- '||v_val_nro_identificacion;
          END IF;
        end if;
        --validar razon social
        if j.RAZ_SOCIAL is null and
           v_tipo_identificador not in (11, 12, 15) then
          v_error := nvl(v_error, '') || '- No se enontró Razón Social.';
        end if;
        --validar cod_tipo_comprobante
        if j.COD_TIPO_COMPROBANTE is null then
          v_error := nvl(v_error, '') ||
                     '- No se enontró Código de Tipo de Comprobante.';
        else
          begin
            v_cod_tipo_comprobante := TO_NUMBER(j.COD_TIPO_COMPROBANTE);
          exception
            when others then
              v_error := nvl(v_error, '') ||
                         '- No se enontró Código de Tipo de Comprobante válido.';
          end;
        end if;
        --validar fecha
        if j.fecha_emision is null then
          v_error := nvl(v_error, '') ||
                     '- No se enontró fecha_emisionde Comprobante.';
        elsif j.fecha_emision < to_date('01/01/2021', 'dd/mm/yyyy') and
              j.CONDICION <> '1' then
          v_error := nvl(v_error, '') ||
                     '- fecha_emisionincorrecta, menor a 01/01/2021';
        end if;
        --validacion de timbrado
        if j.nro_timbrado is null then
          v_error := nvl(v_error, '') || '- No se encontro Timbrado';
        else
          v_timbrado := j.nro_timbrado;
        end if;
        --validacion de nro_comprobante
        if j.nro_comprobante is null then
          if j.COD_TIPO_COMPROBANTE not in ('112', '106') then
            v_error := nvl(v_error, '') ||
                       '- Numero de comprobante no puede ser vacío';
          end if;
        else
          begin
            Select to_number(replace(j.nro_comprobante, '-', '0')) nro_comprobante
              into v_nro_comprobante
              from dual
             where j.nro_comprobante like '___-___-_______'
               and to_number(substr(j.nro_comprobante, 1, 3)) > 0
               and to_number(substr(j.nro_comprobante, 5, 3)) > 0
               and to_number(substr(j.nro_comprobante, 9, 7)) > 0;
          exception
            when others then
              v_error := nvl(v_error, '') ||
                         '- Número de comprobante con formato inválido.';
          end;

        end if;

        --monto_Gravado_10
        if nvl(j.MONTO_GRAVADO_10, 0) < 0 then
          v_error := nvl(v_error, '') ||
                     '-Monto Gravada al 10% es negativo negativo.';
        else
          V_MONTO_GRAVADO_10 := nvl(ROUND(j.MONTO_GRAVADO_10, 0), 0);
        end if;
        --monto_Gravado_5
        if nvl(j.MONTO_GRAVADO_5, 0) < 0 then
          v_error := nvl(v_error, '') ||
                     '-Monto Gravada al 5% es negativo negativo.';
        else
          V_MONTO_GRAVADO_5 := nvl(ROUND(j.MONTO_GRAVADO_5, 0), 0);
        end if;
        --monto_Exento
        if nvl(J.MONTO_EXENTO, 0) < 0 then
          v_error := nvl(v_error, '') ||
                     '-Monto Exnto es negativo negativo.';
        else
          V_MONTO_EXENTO := nvl(ROUND(J.MONTO_EXENTO, 0), 0);
        end if;
        --MONTO_TOTAL
        if nvl(J.MONTO_TOTAL, 0) < 0 then
          v_error := nvl(v_error, '') ||
                     '-Monto total es negativo negativo.';
        else
          V_MONTO_TOTAL := nvl(ROUND(J.MONTO_TOTAL, 0), 0);
        end if;
        --condicion venta
        if j.condicion is null and j.COD_TIPO_COMPROBANTE = '109' then
          v_error := nvl(v_error, '') ||
                     '- Es necesario definir una condicion de venta';
        else
          v_condicion := nvl(j.condicion, 1);
        end if;
        --moneda extranjera
        v_moneda_extranjera := nvl(j.MONEDA_EXTRANJERA, 'N');
        --imputa iva
        if V_MONTO_GRAVADO_10 + V_MONTO_GRAVADO_5 + V_MONTO_EXENTO > 0 then
          v_imputa_iva := 'S';
        else
          v_imputa_iva := 'N';
        end if;
        --Notas de creditos
        if j.COD_TIPO_COMPROBANTE in ('110', '111') then
          --si es NC
          --nro_comprobante_asociado
          if j.FACTURA_ASOCIADA is null then
            v_error := nvl(v_error, '') ||
                       '- Es necesario definir un numero de comprobante asociado a la Nota de Crédito';
          else
            begin
              Select to_number(replace(j.FACTURA_ASOCIADA, '-', '0')) nro_comprobante
                into v_nro_comprobante_ref
                from dual
               where j.FACTURA_ASOCIADA like '___-___-_______'
                 and to_number(substr(j.FACTURA_ASOCIADA, 1, 3)) > 0
                 and to_number(substr(j.FACTURA_ASOCIADA, 5, 3)) > 0
                 and to_number(substr(j.FACTURA_ASOCIADA, 9, 7)) > 0;
            exception
              when others then
                v_error := nvl(v_error, '') ||
                           '- Número de comprobante asociado con formato inválido.';
            end;
          end if;
          --nro_timbrado_asociado
          if j.TIMBRADO_ASOCIADO is null then
            v_error := nvl(v_error, '') ||
                       '- Es necesario definir un numero de timbrado asociado a la Nota de Crédito';
          end if;
        end if;
        --------------------------------------FIN VENTAS---------------------------------------------
      elsif j.tipo_registro = 2 then
        --Compras--2
        if j.cod_tip_documento is null then
          v_error := nvl(v_error, '') ||
                     '- No se enontró Tipo de Identificacion.';
        else
          if j.COD_TIPO_COMPROBANTE not in ('101', '107') then
            v_tipo_identificador :=  11;
          else
              begin
               v_tipo_identificador :=  j.cod_tip_documento;
              exception
                 when others then
                  v_error:= nvl(v_error,'')||'- No se enontró Tipo de Identificacion válido.';
              end;
            /*END IF;*/
          end if;

        end if;
        --valida nro_identificador--3
        if j.NRO_IDENTIFICADOR is null then
          v_error := nvl(v_error, '') ||
                     '- No se enontró Número de Documento.';
        else
          v_val_nro_identificacion :=  fu_val_tip_identificacion(v_tipo_identificador, j.NRO_IDENTIFICADOR);
          if v_val_nro_identificacion <> 'OK' THEN
             v_error := nvl(v_error, '')||
                     '- '||v_val_nro_identificacion;
          END IF;
        end if;
        --validar razon social--4
        if j.RAZ_SOCIAL is null and v_tipo_identificador not in (11, 12) then
          v_error := nvl(v_error, '') || '- No se enontró Razón Social.';
        end if;
        --validar cod_tipo_comprobante--5
        if j.COD_TIPO_COMPROBANTE is null then
          v_error := nvl(v_error, '') ||
                     '- No se enontró Código de Tipo de Comprobante.';
        else
          begin
            v_cod_tipo_comprobante := to_number(j.COD_TIPO_COMPROBANTE);
          exception
            when others then
              v_error := nvl(v_error, '') ||
                         '- 2 No se enontró Código de Tipo de Comprobante válido.'||sqlerrm;
          end;

        end if;
        --validar fecha--6
        if j.fecha_emision is null then
          v_error := nvl(v_error, '') ||
                     '- No se enontró fecha_emisionde Comprobante.';
        elsif j.fecha_emision < to_date('01/01/2021', 'dd/mm/yyyy') and
              j.CONDICION <> '1' then
          v_error := nvl(v_error, '') ||
                     '- fecha_emisionincorrecta, menor a 01/01/2021';
        end if;
        --validacion de timbrado--7
        if j.nro_timbrado is null then
          if j.cod_tipo_comprobante = 107 then
            v_timbrado := 0;
          else
            v_error := nvl(v_error, '') || '- No se encontró Timbrado';
          end if;
        else
          v_timbrado := j.nro_timbrado;
        end if;
        --validacion de nro_comprobante--8
        if j.nro_comprobante is null then
          if j.COD_TIPO_COMPROBANTE not in ('102', '106', '107') then
            v_error := nvl(v_error, '') ||
                       '- Numero de comprobante no puede ser vacío';
          end if;
        else
          begin
            Select to_number(replace(j.nro_comprobante, '-', '0')) nro_comprobante
              into v_nro_comprobante
              from dual
             where j.nro_comprobante like '___-___-_______'
               and to_number(substr(j.nro_comprobante, 1, 3)) > 0
               and to_number(substr(j.nro_comprobante, 5, 3)) > 0
               and to_number(substr(j.nro_comprobante, 9, 7)) > 0;
          exception
            when others then
              v_error := nvl(v_error, '') ||
                         '- Número de comprobante con formato inválido.';
          end;

        end if;

        --monto_Gravado_10--9
        if nvl(j.MONTO_GRAVADO_10, 0) < 0 then
          v_error := nvl(v_error, '') ||
                     '-Monto Gravada al 10% es negativo.';
        else
          if j.COD_TIPO_COMPROBANTE not in ('101', '104', '112') then
            V_MONTO_GRAVADO_10 := nvl(ROUND(j.MONTO_GRAVADO_10, 0), 0);
          else
            V_MONTO_GRAVADO_10 := 0;
          end if;
        end if;
        --monto_Gravado_5--10
        if nvl(j.MONTO_GRAVADO_5, 0) < 0 then
          v_error := nvl(v_error, '') ||
                     '-Monto Gravada al 5% es negativo.';
        else
          if j.COD_TIPO_COMPROBANTE not in ('101', '104', '112') then
            V_MONTO_GRAVADO_5 := nvl(ROUND(j.MONTO_GRAVADO_5, 0), 0);
          else
            V_MONTO_GRAVADO_5 := 0;
          end if;
        end if;
        --monto_Exento--11
        if nvl(J.MONTO_EXENTO, 0) < 0 then
          v_error := nvl(v_error, '') || '-Monto Exnto es negativo.';
        else
          if j.COD_TIPO_COMPROBANTE not in ('101', '104', '112') then
            V_MONTO_EXENTO := nvl(ROUND(j.monto_exento, 0), 0);
          else
            V_MONTO_EXENTO := 0;
          end if;
        end if;
        --MONTO_TOTAL--12
        if nvl(J.MONTO_TOTAL, 0) < 0 then
          v_error := nvl(v_error, '') || '-Monto total es negativo.';
        else
          V_MONTO_TOTAL := nvl(ROUND(J.MONTO_TOTAL, 0), 0);
        end if;
        --condicion venta
        if j.condicion is null and j.COD_TIPO_COMPROBANTE = 109 then
          v_error := nvl(v_error, '') ||
                     '- Es necesario definir una condicion de venta';
        else
          v_condicion := nvl(j.condicion, 1);
        end if;
        --moneda extranjera
        v_moneda_extranjera := nvl(j.MONEDA_EXTRANJERA, 'N'); ---calcular este valor
        --imputa iva
        if V_MONTO_GRAVADO_10 + V_MONTO_GRAVADO_5 + V_MONTO_EXENTO > 0 then
          v_imputa_iva := 'S';
          v_no_imputa  := 'S';
        else
          v_imputa_iva := 'N';
          v_no_imputa  := 'N';
        end if;
        --
        --Notas de creditos
        if j.COD_TIPO_COMPROBANTE in ('110', '111') then
          --si es NC
          --nro_comprobante_asociado
          if j.FACTURA_ASOCIADA is null then
            v_error := nvl(v_error, '') ||
                       '- Es necesario definir un numero de comprobante asociado a la Nota de Crédito';
          else
            begin
              Select to_number(replace(j.FACTURA_ASOCIADA, '-', '0')) nro_comprobante
                into v_nro_comprobante_ref
                from dual
               where j.FACTURA_ASOCIADA like '___-___-_______'
                 and to_number(substr(j.FACTURA_ASOCIADA, 1, 3)) > 0
                 and to_number(substr(j.FACTURA_ASOCIADA, 5, 3)) > 0
                 and to_number(substr(j.FACTURA_ASOCIADA, 9, 7)) > 0;
            exception
              when others then
                v_error := nvl(v_error, '') ||
                           '- Número de comprobante asociado con formato inválido.';
            end;
          end if;
          --nro_timbrado_asociado
          if j.TIMBRADO_ASOCIADO is null then
            v_error := nvl(v_error, '') ||
                       '- Es necesario definir un numero de timbrado asociado a la Nota de Crédito';
          end if;
        end if;

      end if;
    end if;
    if v_error is null then
      -- si no hay errror guardar el registro en la tabla final y actualizar en el temporal
      begin

        insert into CB_RG_90( tipo_registro,
							  cod_tip_documento,
							  nro_identificador,
							  raz_social,
							  cod_tipo_comprobante,
							  fecha_emision,
							  nro_timbrado,
							  nro_comprobante,
							  monto_gravado_10,
							  monto_gravado_5,
							  monto_exento,
							  monto_total,
							  condicion,
							  moneda_extranjera,
							  imputa_iva,
							  imputa_ire,
							  imputa_irp_rsp,
							  no_imputa,
							  factura_asociada,
							  timbrado_asociado,
							  fec_proceso,
							  periodo,
							  generado,
							  usu_insercion,
							  fec_insercion,
							  usu_modificacion,
							  fec_modificacion)
        values
          (j.tipo_registro,
           v_tipo_identificador,
           j.NRO_IDENTIFICADOR,
           j.RAZ_SOCIAL,
           j.cod_tipo_comprobante,
           j.fecha_emision,
           v_timbrado,
           j.nro_comprobante,
           v_monto_gravado_10,
           v_monto_gravado_5,
           V_MONTO_EXENTO,
           V_MONTO_TOTAL,
           v_condicion,
           v_moneda_extranjera,
           v_imputa_iva,
           'N' /*j.imputa_ire*/,
           'N' /*j.imputa_irp_rsp*/,
           v_no_imputa,
           j.factura_asociada,
           j.timbrado_asociado,
           TRUNC(SYSDATE),
           TO_CHAR(J.fecha_emision, 'mm/yyyy'),
           null,
           USER,
           SYSDATE,
           USER,
           SYSDATE);
      exception
        when DUP_VAL_ON_INDEX then
          V_ERROR := 'Registro duplicado';
        when others then
          V_ERROR := 'Error al insertar registro en la tabla CB_RG_90. ' ||
                     sqlerrm;
      end;
    end if;
    update CB_RG_90_TMP T
       set T.procesado = 'S', T.ERROR = V_ERROR
     where t.rowid = j.rowid;
    commit;
  end loop;

END;
/

