CREATE OR REPLACE FUNCTION IT.FUG_WSI_ABM_CLI_CTA (p_nro_tarjeta varchar2)
RETURN varchar2 IS

/* Funcion para enviar registro de cuentas de tarj. por medio de Webservices a la Procesadora */

  CURSOR c_cuentas IS
     SELECT '{"TitNroDoc": "'      || pe.nro_documento || '",
              "TitTpoPers": "'     || pe.tipo || '",
              "TitTpoDoc": "'      || CASE TRIM(td.abreviatura)
                                      WHEN 'CI' THEN 'CIP'
                                      ELSE TRIM(td.abreviatura)
                                      END || '",
              "TitNombre1": "'     || REPLACE(REPLACE(REPLACE(substr(pf.pri_nombre,1,20),';',' '),chr(9),''),chr(10),'') ||  '",
              "TitNombre2": "'     || REPLACE(REPLACE(REPLACE(substr(pf.seg_nombre,1,20),';',' '),chr(9),''),chr(10),'') || '",
              "TitApellido1": "'   || REPLACE(REPLACE(REPLACE(substr(pf.pri_apellido,1,20),';',' '),chr(9),''),chr(10),'') || '",
              "TitApellido2": "'   || REPLACE(REPLACE(REPLACE(substr(pf.seg_apellido,1,20),';',' '),chr(9),''),chr(10),'') || '",
              "TitRazonSoc": '     || 'null' || ',
              "TitDenComercial": ' || 'null' || ',
              "TitPaisDoc": "'     || bp.ref_externa || '",
              "TitSexo": "'        || pf.cod_sexo || '",
              "TitFchNac": "'      || to_char(pf.fec_nacimiento, 'DD/MM/YY') || '",
              "TitLugNac": "'      || substr(bp.descripcion, 1, 15) || '",
              "TitRUCExtrac": "'   || decode(pe.tip_iva,'CO',TRIM(pe.nro_documento)|| '-' ||
                                      REPLACE(fue_obt_ruc_dig_verificador(TRIM(pe.nro_documento)),'-', ''),NULL) || '",
              "TitEstCivil": "'    || decode(pf.est_civil, 'S', 'S', 'C', 'C', 'V', 'V', 'D', 'D', 'B', 'C', 'S') || '",
              "TitOcupacion": "'   || nvl(pr.ref_externa, 1807) || '",
              "TitEmail": "'       || REPLACE(REPLACE(REPLACE(substr(pe.dir_correo, 1, 60),';',' '), chr(9), ''),chr(10), '') || '",
              "TitTpoDocNuevo": "' || CASE TRIM(td.abreviatura)
                                      WHEN 'CI' THEN 'CIP'
                                      ELSE TRIM(td.abreviatura)
                                      END || '",
              "TitNroDocNuevo": "' || pe.nro_documento || '",
              "NroControl": '      || 'null' ||',
              "NroCuenta": "'      || ct.nro_cuenta || '",
              "CodAfinidad":'      || 'null' || ',
              "TpoCuenta":   '     || 'null' || ',
              "DirecRecibo": '     || 'v_dir_recibo'|| ',
              "DirecExtracto1": '  || 'v_dir_ext1'  || ',
              "DirecExtracto2": '  || 'v_dir_ext2'  || ',
              "DirecExtracto3": '  || 'v_dir_ext3'  || ',
              "Departamento": '    || 'v_cod_dep'   || ',
              "Ciudad": '          || 'v_cod_ciudad'|| ',
              "Zona": '            || 'null'        || ',
              "NroTelefono": '     || 'v_nro_tel'   || ',
              "NroCelular": '      || 'v_nro_cel'   || ',
              "DirecEmail":"'      || REPLACE(REPLACE(REPLACE(substr(pe.dir_correo, 1,60),';', ''),chr(9),''),chr(10),'') || '",
              "CodSucursal": '     || 'null' || ',
              "NroDocOfiCta": '    || 'null' || ',
              "TpoDocOfiCta": '    || 'null' || ',
              "CuentaVIP": '       || 'null' || ',
              "Franqueo": '        || 'null' || ',
              "AplicaSegVida": "'  || 'S'    || '",
              "CobraCargo": "'     || 'S'    || '",
              "TipoCosto": "'      || 'N'    || '",
              "RetenerExtracto": "'|| 'S'    || '",
              "MotivoRetencion": "'|| nvl(fug_obt_pardinamico('MOT_RET_SOL_CLIENTE'), 5) || '",
              "TpoCierre": '       || 'null' || ',
              "EmpresaAdherida": ' || 'null' || ',
              "CalificacionBCP": ' || 'null' || ',
              "Situacion": '       || 'null' || ',
              "CodClienteEnt": '   || 'null' || ',
              "NroSocio": '        || 'null' || ',
              "BonosCobranding": ' || 'null' || ',
              "TpoLinea1Normal": "' || CASE WHEN ct.lin_credito IS NULL THEN NULL ELSE 1 END || '",
              "LineaCreditoNormal":"'|| ct.lin_credito || '",
              "TpoLinea2Cuota": '  || 'null' || ',
              "LineaCreditoCuota":'|| 'null' || ',
              "PersonalizaTTI": '  || 'null' || ',
              "CodTTICorriente": ' || 'null' || ',
              "TasaInteresCorriente": ' || 'null' || ',
              "CodTTIMoratorio": ' || 'null' || ',
              "TasaInteresMora": ' || 'null' || ',
              "CodTTICompra": '    || 'null' || ',
              "TasaInteresCompra":'|| 'null' || ',
              "PersPagoMinimo": '  || 'null' || ',
              "PorcPagoMinimo": '  || 'null' || ',
              "ImpMinPagoMin": '   || 'null' || ',
              "ImpFijoPagoMin": '  || 'null' || ',
              "ModoPago": '        || 'null' || ',
              "TpoCtaBancaria": '  || 'null' || ',
              "CtaBancaria": '     || 'null' || ',
              "TipoPago": '        || 'null' || ',
              "ValorCGF": '        || 'null' || ',
              "TpoTasaFinac": '    || 'null' || ',
              "FactorMultipVIP": ' || 'null' || ',
              "CobrandingId": '    || 'null' || ',
              "CodeuNroDoc": '     || 'null' || ',
              "CodeuTpoPers": '    || 'null' || ',
              "CodeuTpoDoc": '     || 'null' || ',
              "CodeuNombre1": '    || 'null' || ',
              "CodeuNombre2": '    || 'null' || ',
              "CodeuApellido1": '  || 'null' || ',
              "CodeuApellido2": '  || 'null' || ',
              "CodeuSexo": '       || 'null' || ',
              "CodeuFchNac": '     || 'null' || ',
              "CodeuLugNac": '     || 'null' || ',
              "CodeuEstCivil": '   || 'null' || ',
              "CodeuOcupacion": '  || 'null' || ',
              "CodeuEmail": '      || 'null' || ',
              "OfiNroDoc": '       || 'null' || ',
              "OfiTpoPers": '      || 'null' || ',
              "OfiTpoDoc": '       || 'null' || ',
              "OfiNombre1": '      || 'null' || ',
              "OfiNombre2": '      || 'null' || ',
              "OfiApellido1": '    || 'null' || ',
              "OfiApellido2": '    || 'null' || ',
              "OfiSexo": '         || 'null' || ',
              "OfiFchNac": '       || 'null' || ',
              "OfiLugNac": '       || 'null' || ',
              "OfiEstCivil": '     || 'null' || ',
              "OfiOcupacion": '    || 'null' || ',
              "OfiEmail": '        || 'null' || ',
              "CostoNoAplicar": '  || 'null' || ',
              "AplicaImpuesto": '  || 'null' || ',
              "UsuActualizacion":"'|| user   || '",
              "MotNovCuenta": '    || 'null' || ',
              "CupAlt": '          || 'null' || '}' JSON_regs,
              ta.nro_cuenta, ta.nro_tarjeta, pe.cod_persona, ct.nro_solicitud
       FROM ba_personas       pe, 
            ba_per_fisicas    pf, 
            ta_tarjetas       ta, 
            ta_cta_tarjetas   ct, 
            ge_cta_clientes   cl,
            ba_tip_documentos td,
            ba_paises         bp,
            ba_profesiones    pr
      WHERE pe.cod_persona=pf.cod_persona 
        AND cl.cod_persona=pe.cod_persona 
        AND cl.nro_cuenta=ct.nro_cuenta 
        AND cl.cod_persona=ta.cod_persona
        AND ct.nro_cuenta=ta.nro_cuenta
        AND pe.cod_tip_documento=td.cod_tip_documento 
        AND pf.cod_pai_nacionalidad=bp.cod_pais(+) 
        AND pf.cod_profesion=pr.cod_profesion(+)
        AND ta.nro_tarjeta=p_nro_tarjeta;

    v_inicio               varchar2(10) := '[';
    v_fin                  varchar2(10) := ']';
    v_json                 clob;
    ---
    v_respuesta            TYP_POSTRESPUESTACLOB;
    v_url_web_ser_bancard  ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('WSI_ABM_CTA_BANCARD');
    v_metodo               VARCHAR2(5) := 'POST';
    v_result               varchar2(4000);
    --
    v_con_error            varchar2(3):= 'NO';
    v_con_errores          number:=0;
    v_con_exito            number:=0;
    v_hay_datos            varchar2(1):='N';
    --------
    v_json_regs            clob;
    v_tip_envio            ge_dir_envios.tip_envio%TYPE;
    v_nro_solicitud        ta_solicitudes.nro_solicitud%type;
    v_nro_cuenta           ta_cta_tarjetas.nro_cuenta%type;
    v_dir_cliente          ta_env_cuentas.direccion%TYPE;
    v_dir_recibo           ta_env_cuentas.dir_recibo%TYPE;
    v_edificio             ba_direcciones.edificio%type;
    v_piso                 ba_direcciones.piso%type;
    v_dpto                 ba_direcciones.departamento%type;
    v_cod_per_titular      ba_personas.cod_persona%type;
    v_cod_ciu_direccion    ba_ciudades.ref_externa%TYPE;
    v_cod_ciu_direccion2   ba_ciudades.ref_externa%TYPE;
    v_des_ciudad           ba_ciudades.descripcion%TYPE;
    v_des_ciudad2          ba_ciudades.descripcion%TYPE;
    v_cod_dep_direccion    ba_departamentos.ref_externa%TYPE;
    v_cod_dep_direccion2   ba_departamentos.ref_externa%TYPE;
    v_tel_cliente          VARCHAR2(25);
    v_dir_extendida        VARCHAR2(150);
    v_nro_cel_titular      VARCHAR2(20);
    
    --procedimiento interno de manejo de respuesta (formateo)
    PROCEDURE lp_pro_respuesta(p_respuesta varchar2,
                               p_codigoError varchar2,
                               p_error varchar2,
                               p_descripcionRespuesta varchar2,
                               p_status_code varchar2) IS
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    v_resp_json typ_json;
    v_resp_num number;
    v_resp_err varchar2(4000);

    BEGIN
       IF p_error != 'S' THEN
          --controlamos que el servicio responda con exito (200)
          IF p_status_code = '200' THEN
             v_resp_json := typ_json(p_respuesta);--convertimos a json la respuesta -> estructura json {"result":"999"}
             --Un error suele ser la respuesta {"result":"Usuario/Contrase??a Inactiva"}
             --entonces tratar la respuesta como char
             IF length(pag_jex.get_string(v_resp_json, 'result')) > 3 THEN--respuesta caracter
                v_resp_num := null;--para captuar el error marcamos a null
             ELSE
                v_resp_num := to_number(pag_jex.get_string(v_resp_json, 'result'));--obtenemos el nro de respuesta
             END IF;
             --v_resp_num = 0 (Sin errores) mayor a 0 (con errores)--se le encamina al usuario para que revise en bancard
             IF v_resp_num > 0 THEN
                v_con_error:='SI';--se marca que en el proceso existe errores de envio de registros.
                v_con_errores:= v_con_errores+v_resp_num;
             --sin errores
             ELSIF v_resp_num = 0 THEN
                v_con_exito:=v_con_exito+1;--acumulamos registros enviados correctamente
             ELSIF v_resp_num is null THEN
                v_con_error:='SI*';
                v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||pag_jex.get_string(v_resp_json, 'result');
             END IF;
          --errores que no deben continuar con el proceso de envio se marca con (SI*)
          --el servicio Web no ha respondido satisfactoriamente.(diferente a 200 con errores gestionados en el WS)
          ELSIF p_status_code ='400' THEN--error de formateo de datos en los parametros enviados
             v_result:= 'Error al utilizar Servicios WEB Bancard Conector: Parametros de envio invalidos: '||p_respuesta;
             v_con_error:='SI*';
          ELSIF p_status_code ='404' THEN--Servicio no disponible, servidor de bancarconector caido
             v_result:= 'Error Servicios de conexion a Bancard no disponibles, utilizar operativa contingente';
             v_con_error:='SI*';
          ELSIF p_status_code in('503','412','500') THEN--errores soportados en BancardConector
             v_resp_json := typ_json(p_respuesta);
             v_resp_err := substr(pag_jex.get_string(v_resp_json, 'msgError'), 4000);--obtenemos el mensaje de error

             v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||v_resp_err;
             v_con_error:='SI*';

             IF p_status_code = '503' THEN
                v_result := 'Error, Servicios Web de Bancard Inactivos.';
             END IF;
          ELSE--otros errores no soportados
             v_result:= 'Error al utilizar Servicios WEB Bancard: '||p_descripcionRespuesta||'-'||p_codigoError||'-'||p_error;
             v_con_error:='SI*';
          END if;
       ELSIF p_error = 'S' THEN
          v_con_error:='SI*';
          v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||p_descripcionRespuesta;
       END IF;
    END lp_pro_respuesta;
    --procedimiento interno para el registro de los mensajes
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
         raise_application_error(-20000, sqlerrm);
    END;
     
    --procedimiento interno que actualiza ta_tar_nominadas
    PROCEDURE LP_ACT_NOMINADAS(p_nro_cuenta IN VARCHAR2, p_nro_tarjeta IN VARCHAR2) is
       PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    BEGIN
       IF v_con_error = 'SI*' AND instr(upper(v_result), 'SUBMITIDO') > 0 THEN
          UPDATE ta_tar_nominadas
             SET env_cuenta = 'S'
           WHERE nro_cuenta = p_nro_cuenta
             AND nro_tarjeta = p_nro_tarjeta;
       END IF;
       COMMIT;
    EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20000, sqlerrm);
    END;
    
    PROCEDURE lp_dir_envio IS
      v_cod_departamento  ba_departamentos.cod_departamento%type := NULL;
      v_cod_departamento2 ba_departamentos.cod_departamento%type := NULL;
    BEGIN
      /*Carga los datos de la direccion y telefono de envio*/
      
      v_piso               := NULL;
      v_dpto               := NULL;
      v_edificio           := NULL;
      v_dir_recibo         := NULL;
      v_des_ciudad         := NULL;
      v_des_ciudad2        := NULL;
      v_tel_cliente        := NULL;
      v_dir_cliente        := NULL;
      v_dir_extendida      := NULL;
      v_nro_cel_titular    := NULL;
      v_cod_ciu_direccion  := NULL;
      v_cod_ciu_direccion2 := NULL;
      v_cod_dep_direccion  := NULL;
      v_cod_dep_direccion2 := NULL;
      
      ---1. Leo la vista de acuerdo a los datos que me pasa --------------
      SELECT d.direccion || ' ' || d.numero||' '||d.dir_lateral dir_envio,
             c.descripcion des_ciudad,
             c2.descripcion des_ciudad2,
             t.area || decode(t.area, NULL, NULL, '-') || t.telefono tel_cliente,
             c.ref_externa cod_ref_ciudad,
             c2.ref_externa cod_ref_ciudad2,
             nvl(de.ref_externa, 11) cod_ref_departamento, --codigo de departamento de la procesadora, x defecto 11=central
             nvl(de2.ref_externa, 11) cod_ref_departamento2, --codigo de departamento de la procesadora, x defecto 11=central
             de.cod_departamento,
             de2.cod_departamento,
             d.edificio,
             d.piso,
             d.departamento,
             (SELECT x.area||x.telefono
                   FROM ba_telefonos x
                  WHERE x.cod_persona = d.cod_persona
                    AND tip_linea = 'C'
                    AND rownum < 2)
        INTO v_dir_cliente,
             v_des_ciudad,
             v_des_ciudad2,
             v_tel_cliente,
             v_cod_ciu_direccion,
             v_cod_ciu_direccion2,
             v_cod_dep_direccion,
             v_cod_dep_direccion2,
             v_cod_departamento,
             v_cod_departamento2,
             v_edificio,
             v_piso,
             v_dpto,
             v_nro_cel_titular
        FROM ba_barrios         b,
             ba_departamentos   de,
             ba_departamentos   de2,
             ba_ciudades        c,
             ba_ciudades        c2,
             ba_paises          p,
             ba_paises          p2,
             ba_telefonos       t,
             ba_direcciones     d,
             ge_dir_retenciones o
       WHERE p.cod_pais(+) = d.cod_pais
         AND de.cod_departamento(+) = c.cod_departamento
         AND c.cod_pais(+) = d.cod_pais
         AND c.cod_ciudad(+) = d.cod_ciudad
         AND b.cod_pais(+) = d.cod_pais
         AND b.cod_ciudad(+) = d.cod_ciudad
         AND b.cod_barrio(+) = d.cod_barrio
            --
         AND p2.cod_pais(+) = o.cod_pais
         AND de2.cod_departamento(+) = c2.cod_departamento
         AND c2.cod_pais(+) = o.cod_pais
         AND c2.cod_ciudad(+) = o.cod_ciudad
            --
         AND t.cod_persona(+) = d.cod_persona
         AND t.principal(+) = 'S'
         AND d.cod_persona = v_cod_per_titular
         AND rownum = 1;
      
      --
      IF v_tel_cliente IS NULL THEN
         BEGIN
            SELECT x.area || decode(x.area, NULL, NULL, '-') || x.telefono
              INTO v_tel_cliente
              FROM ba_telefonos x
             WHERE x.cod_persona = v_cod_per_titular
               AND x.principal = 'N'
               AND x.cod_telefono = (SELECT MIN(y.cod_telefono)
                                       FROM ba_telefonos y
                                      WHERE y.cod_persona = v_cod_per_titular
                                        AND y.principal = 'N'
                                        AND y.telefono IS NOT NULL)
               AND rownum = 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_tel_cliente := NULL;
         END;
      END IF;

      --Busco la direccion de recibo del plastico, viene de la solicitud
      IF v_nro_solicitud IS NOT NULL THEN
         BEGIN
            SELECT substr(decode(t.tip_envio, 'D', d.direccion || ' ' || d.numero|| ' ' ||d.dir_lateral, 'C',
                                 'CASILLERO: ' || t.referencia, 'A',
                                 'CASILLA DE CORREO: ' || t.referencia, 'R',
                                 'RETENER EN ' || o.descripcion), 1, 35) dir_recibo, t.tip_envio
              INTO v_dir_recibo, v_tip_envio
              FROM ba_direcciones d, ge_dir_retenciones o, ta_solicitudes t
             WHERE t.nro_solicitud = v_nro_solicitud
               AND ((t.tip_envio = 'D' AND d.cod_persona = t.cod_persona AND
                   d.cod_direccion = t.referencia) OR
                   (t.tip_envio = 'R' AND o.cod_dir_retencion = t.referencia))
               AND rownum = 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_dir_recibo := NULL;
         END;
      ELSE
         IF v_nro_cuenta IS NOT NULL THEN
            BEGIN
               SELECT substr(decode(e.tip_envio, 'D', d.direccion || ' ' || d.numero|| ' ' ||d.dir_lateral, 'C',
                                    'CASILLERO: ' || e.referencia, 'A',
                                    'CASILLA DE CORREO: ' || e.referencia, 'R',
                                    'RETENER EN ' || o.descripcion), 1, 35) dir_recibo, e.tip_envio
                 INTO v_dir_recibo, v_tip_envio
                 FROM ba_direcciones d, ge_dir_retenciones o, ge_dir_envios e, ta_tarjetas t
                WHERE t.nro_cuenta = v_nro_cuenta
                  AND t.cod_persona = v_cod_per_titular
                  AND e.cod_persona = t.cod_persona
                  AND e.tip_envio = t.tip_envio
                  AND e.referencia = t.referencia
                  AND (e.nro_cuenta = v_nro_cuenta OR e.nro_cuenta IS NULL)
                  AND d.cod_persona(+) = e.cod_persona
                  AND d.cod_direccion(+) = e.referencia
                  AND o.cod_dir_retencion(+) = e.referencia
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_dir_recibo := NULL;
            END;
         END IF;
      END IF;
      ---Si el tipo de envio es Retencion asignar los valores de ciudad y pais a las variables correspondientes
      IF v_tip_envio = 'R' THEN
         v_des_ciudad        := v_des_ciudad2;
         v_cod_ciu_direccion := v_cod_ciu_direccion2;
         v_cod_dep_direccion := v_cod_dep_direccion2;
      END IF;
      --
      IF v_dir_recibo IS NULL THEN
         v_dir_recibo := substr(v_dir_cliente, 1, 35);
      END IF;

      -- Armar la direccion extendida--
      SELECT substr(v_dir_cliente ||decode(v_edificio,null,null,' Edif. ')||v_edificio
             || decode(v_piso,null,null,' Piso. ')|| v_piso
             || decode(v_dpto,null,null,' Dpto. ')|| v_dpto
             || decode(v_des_ciudad, NULL, NULL, ' - ') || v_des_ciudad, 1, 150)
        INTO v_dir_extendida
        FROM dual;
      --- Jira: MDP-MOD_PRO_ALT_MAS_ABM
      IF nvl(v_cod_departamento,11) = 11 AND v_cod_ciu_direccion IS NULL THEN
         v_cod_ciu_direccion  := 1;
      END IF;
      IF nvl(v_cod_departamento2,11) = 11 AND v_cod_ciu_direccion2 IS NULL THEN
         v_cod_ciu_direccion2 := 1;
      END IF;
      ---
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 ' Al Obt.Dir.envio: ' || v_cod_per_titular ||
                                 ' Cuenta: '|| v_nro_cuenta||sqlerrm);
   END lp_dir_envio;
    
/*SE ENVIARA DE A 1 REGISTRO AL WS DE BANCARD*/
BEGIN

   FOR c IN c_cuentas LOOP
      v_nro_cuenta := c.nro_cuenta;
      v_nro_solicitud := c.nro_solicitud;
      v_cod_per_titular := c.cod_persona;
      lp_dir_envio;
      -- DDSI-513 Se agregan REPLACES para limpiar caracteres (enter, tab, espacios).
      v_json_regs := REPLACE(c.json_regs, 'v_dir_recibo', '"'||nvl(REPLACE(REPLACE(REPLACE(substr(v_dir_recibo, 1, 60),';',''),chr(9),''),chr(10),''), 'BORRAR')||'"');
      v_json_regs := REPLACE(v_json_regs, 'v_dir_ext1',   '"'||rpad(nvl(REPLACE(REPLACE(REPLACE(substr(v_dir_extendida,   1, 50),';',''),chr(9),''),chr(10),''),'BORRAR'),50,' ')||'"');
      v_json_regs := REPLACE(v_json_regs, 'v_dir_ext2',   '"'||rpad(nvl(REPLACE(REPLACE(REPLACE(substr(v_dir_extendida,  51, 50),';',''),chr(9),''),chr(10),''),'BORRAR'),50,' ')||'"');
      v_json_regs := REPLACE(v_json_regs, 'v_dir_ext3',   '"'||rpad(nvl(REPLACE(REPLACE(REPLACE(substr(v_dir_extendida, 101, 50),';',''),chr(9),''),chr(10),''),'BORRAR'),50,' ')||'"');
      v_json_regs := REPLACE(v_json_regs, 'v_cod_dep',    '"'||nvl(REPLACE(REPLACE(REPLACE(substr(v_cod_dep_direccion, 1, 60),';',''),chr(9), ''),chr(10),''), 999)||'"');
      v_json_regs := REPLACE(v_json_regs, 'v_cod_ciudad', '"'||nvl(REPLACE(REPLACE(REPLACE(substr(v_cod_ciu_direccion, 1, 60),';',''),chr(9),''),chr(10),''), 999)||'"');
      v_json_regs := REPLACE(v_json_regs, 'v_nro_tel',    '"'||nvl(REPLACE(REPLACE(REPLACE(substr(v_tel_cliente, 1, 60),';',''),chr(9),''),chr(10),''), ' - ')||'"');
      v_json_regs := REPLACE(v_json_regs, 'v_nro_cel',    '"'||nvl(REPLACE(REPLACE(REPLACE(substr(v_nro_cel_titular, 1, 60),';',''),chr(9), ''),chr(10),''), ' - ')||'"');
      v_hay_datos:= 'S' ;		                      
      v_json      := to_clob(v_inicio)|| v_json_regs ||to_clob(v_fin);--FORMATEO ARRAY JSON [{objeto}]
      
      --enviamos al WebSevice
      v_respuesta := FUA_WSI_ENV_POST(v_json, v_url_web_ser_bancard, v_metodo);

      -- bitacora de logs
      lp_reg_operacion('/'||v_metodo||'/'||v_url_web_ser_bancard||'/'||v_json, substr(v_respuesta.error || ' - ' ||
      v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));
      --procesamos la respuesta
      lp_pro_respuesta(v_respuesta.respuesta,
                         v_respuesta.codigoError,
                         v_respuesta.error,
                         v_respuesta.descripcionRespuesta,
                         v_respuesta.status_code);
      lp_act_nominadas(c.nro_cuenta, c.nro_tarjeta);
   END LOOP;

   --si se procesaron datos
   IF v_hay_datos = 'S' THEN
      IF v_con_error = 'SI*' THEN
         IF instr(upper(v_result), 'SUBMITIDO') = 0 THEN
            ROLLBACK;
         END IF;
         RETURN 'CTA-'||v_result;
      ELSIF v_con_error = 'SI' THEN
         COMMIT;
         RETURN 'CTA-Envio realizado, (Registros correctos ('||v_con_exito||'), Registros incorrectos ('||v_con_errores||') Ver en pantalla Azul de bancard Los datos incorrectos';
      ELSIF v_con_error = 'NO' THEN
         COMMIT;
         RETURN 'CTA-Envio realizado exitosamente!';
      END IF;
   ELSE-- si no se procesaron datos
      RETURN 'CTA-No existen registros de a enviar';
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20000, 'CTA*Error al enviar : '||SQLERRM);
END FUG_WSI_ABM_CLI_CTA;
/

