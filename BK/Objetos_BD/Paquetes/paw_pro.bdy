create or replace package body it.PAW_PRO is
   --- para parseo XML (segun operacion)
   TYPE typ_xmlReader IS RECORD(   
      cta_debito       bw_ope_programadas.nro_cta_debito%TYPE,
      cta_credito      bw_ope_programadas.nro_cta_credito%TYPE,
      nro_documento    ba_personas.nro_documento%TYPE,
      tip_documento     ba_personas.cod_tip_documento%TYPE,
      monto            ge_movimientos.monto%TYPE,
      cod_moneda       ba_monedas.cod_moneda%TYPE,
      nom_beneficiario VARCHAR2(120),
      dir_beneficiario VARCHAR2(100),   
      cod_swift        VARCHAR2(20),
      tip_mensaje      VARCHAR2(1),     
      cargos           ge_snp_transferencias.tip_cargo%TYPE,
      nom_banco        VARCHAR2(100)
   );
   
   g_cod_mon_local    CONSTANT VARCHAR2(3) := pag_gen.FU_OBT_MON_LOCAL;

   PROCEDURE lp_reg_error(p_mensaje   IN ba_log_mensajeria.mensaje%TYPE,
                          p_respuesta IN ba_log_mensajeria.respuesta%TYPE) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      v_respuesta ba_log_mensajeria.respuesta%TYPE;
   BEGIN
      v_respuesta := substr(p_respuesta, 1, 4000);
      INSERT INTO ba_log_mensajeria
         (mensaje, respuesta)
      VALUES
         (p_mensaje, v_respuesta);
      COMMIT;
   EXCEPTION 
      WHEN OTHERS THEN
         NULL;
   END;
   
   -- obtener datos principales de una sesion
   PROCEDURE pr_obt_dat_sesion(p_sesion     IN VARCHAR2,
                               p_usu_sesion OUT paw_bel.typ_validarSesion) IS
   BEGIN
      SELECT cod_canal, cod_persona, cod_per_vinculada, cod_perfil 
        INTO p_usu_sesion.codigoCanal, p_usu_sesion.codigoPersona, p_usu_sesion.codigoEmpresa, p_usu_sesion.codigoPerfil
        FROM bw_aut_sesiones s
       WHERE s.cod_sesion = paw_bel.depurarAlfanumerico(p_sesion, 32)
         AND trunc(s.fec_insercion) = trunc(SYSDATE);   
   END;
   -- obtener datos de caja
   PROCEDURE pr_obt_caja(p_nro_caja        IN cj_cajas.nro_caja%TYPE,
                         p_cod_ofi_origen OUT cj_cajas.cod_oficina%TYPE,
                         p_cod_usuario    OUT cj_cajas.cod_usuario%TYPE,
                         p_fec_cierre     OUT cj_cajas.fec_hor_cierre%TYPE) IS
   BEGIN
      SELECT c.cod_oficina, c.cod_usuario, c.fec_hor_cierre
        INTO p_cod_ofi_origen, p_cod_usuario, p_fec_cierre
        FROM cj_cajas c
       WHERE c.nro_caja = p_nro_caja
         AND c.estado = 'A'; 
   END;
   
   -- Procedimiento interno para parsear los campos xml segun tipo de operacion
   PROCEDURE lp_obt_dat_xml(p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE, 
                            p_xml             IN VARCHAR2,
                            p_data            OUT typ_xmlReader) IS
                       
      v_xml xmltype;      
   BEGIN
      v_xml := xmltype.createxml(p_xml);         
      -- cuenta debito
      IF v_xml.extract(G_XML_CTA_DEBITO) IS NOT NULL THEN
         p_data.cta_debito := paw_bel.depurarAlfanumerico(v_xml.extract(G_XML_CTA_DEBITO).getStringVal(), 15);            
      END IF;
      -- cuenta credito
      IF v_xml.extract(G_XML_CTA_CREDITO) IS NOT NULL THEN
         p_data.cta_credito := paw_bel.depurarAlfanumerico(v_xml.extract(G_XML_CTA_CREDITO).getStringVal(), 35);
      END IF;
      -- monto
      IF v_xml.extract(G_XML_MONTO) IS NOT NULL THEN
         p_data.monto:= v_xml.extract(G_XML_MONTO).getNumberVal();
      END IF;
      -- numero documento de persona
      IF v_xml.extract(G_XML_NRO_DOCUMENTO) IS NOT NULL THEN
         p_data.nro_documento := paw_bel.depurarTextos(v_xml.extract(G_XML_NRO_DOCUMENTO).getStringVal(), 20);
      END IF;
      -- tipo numero documento de persona
      IF v_xml.extract(G_XML_TIP_NRO_DOC) IS NOT NULL THEN
         p_data.tip_documento := v_xml.extract(G_XML_TIP_NRO_DOC).getNumberVal();
      END IF;
      --transfer a terceros,  necesita moneda credito. 
      IF p_cod_tip_mensaje = '039' AND v_xml.extract(G_XML_COD_CRE_MONEDA) IS NOT NULL THEN
          p_data.cod_moneda := paw_bel.depurarAlfanumerico(v_xml.extract(G_XML_COD_CRE_MONEDA).getStringVal(), 3);
      END IF;
      -- especificos SIPAP
      IF p_cod_tip_mensaje = '036' THEN
         -- codigo swift
         IF v_xml.extract(G_XML_COD_SWIFT) IS NOT NULL THEN
            p_data.cod_swift := paw_bel.depurarAlfanumerico(v_xml.extract(G_XML_COD_SWIFT).getStringVal(), 20);
         END IF;
         -- codigo moneda credito
         IF v_xml.extract(G_XML_COD_CRE_MONEDA) IS NOT NULL THEN
            p_data.cod_moneda := paw_bel.depurarAlfanumerico(v_xml.extract(G_XML_COD_CRE_MONEDA).getStringVal(), 3);
         END IF;
         -- cargos
         IF v_xml.extract(G_XML_CARGOS) IS NOT NULL THEN
            p_data.cargos := paw_bel.depurarAlfanumerico(v_xml.extract(G_XML_CARGOS).getStringVal(), 3);
         END IF;
         -- nombre beneficiario
         IF v_xml.extract(G_XML_NOM_BENEF) IS NOT NULL THEN
            p_data.nom_beneficiario := paw_bel.depurarAlfanumerico(v_xml.extract(G_XML_NOM_BENEF).getStringVal(), 120, 'S');
         END IF;
         -- direccion beneficiario
         IF v_xml.extract(G_XML_DIR_BENEF) IS NOT NULL THEN
            p_data.dir_beneficiario := paw_bel.depurarTextos(v_xml.extract(G_XML_DIR_BENEF).getStringVal(), 100);
         END IF;
         -- tipo mensaje
         IF v_xml.extract(G_XML_TIP_MENSAJE) IS NOT NULL THEN
            p_data.tip_mensaje := substr(v_xml.extract(G_XML_TIP_MENSAJE).getStringVal(), 1, 1);
         END IF;
         -- nombre banco
         IF v_xml.extract(G_XML_NOM_BANCO) IS NOT NULL THEN
            p_data.nom_banco := paw_bel.depurarTextos(v_xml.extract(G_XML_NOM_BANCO).getStringVal(), 100);
         END IF;
      END IF;   
   END;
   
   -- se cargan los datos de una transferencia (propia | tercero) a 'p_boprog'
   FUNCTION lf_obt_transferencia(p_transferencia   IN typ_transferenciaban,
                                 p_boprog          OUT NOCOPY bw_ope_programadas%ROWTYPE) RETURN typ_mensajerespuesta IS
      v_retorno typ_mensajerespuesta := typ_mensajerespuesta;
   BEGIN
      v_retorno.error                := p_transferencia.error;
      v_retorno.nombreRespuesta      := p_transferencia.nombreRespuesta;
      v_retorno.descripcionRespuesta := p_transferencia.descripcionRespuesta;
            
      IF v_retorno.error = 'N' THEN      
         -- poblamos los datos a la variable de salida         
         p_boprog.monto           := p_transferencia.monto;         
         p_boprog.nro_cta_debito  := substr(TRIM(p_transferencia.ctaForDebito), 1, 15);
         p_boprog.nro_cta_credito := substr(TRIM(p_transferencia.ctaForCredito), 1, 35);
         p_boprog.cod_mon_debito  := substr(TRIM(fug_obt_mon_cta(p_boprog.nro_cta_debito)), 1, 3);
         p_boprog.cod_mon_credito := substr(TRIM(fug_obt_mon_cta(p_boprog.nro_cta_credito)), 1, 3);
         p_boprog.nom_cta_credito := substr(TRIM(fug_obt_nom_cuenta(p_boprog.nro_cta_credito)), 1, 100);
         p_boprog.cod_moneda      := p_boprog.cod_mon_debito;

         -- obtenemos la oficina de la cuenta debito
         SELECT c.cod_oficina
           INTO p_boprog.cod_ofi_debito
           FROM ge_cuentas c
          WHERE c.nro_cuenta = p_boprog.nro_cta_debito;               
      END IF;
      
      RETURN v_retorno;
   END;
   
   -- se cargan los datos de una transferencia SIPAP a 'p_boprog'
   FUNCTION lf_obt_tra_snp(p_transferencia   IN typ_transferenciainterbancaria,
                           p_data            IN typ_xmlReader,
                           p_boprog          OUT NOCOPY bw_ope_programadas%ROWTYPE) RETURN typ_mensajerespuesta IS
      v_retorno typ_mensajerespuesta := typ_mensajerespuesta;
      v_extra   bw_ope_programadas.parametros%TYPE := NULL;
   BEGIN
      v_retorno.error                := p_transferencia.error;
      v_retorno.nombreRespuesta      := p_transferencia.nombreRespuesta;
      v_retorno.descripcionRespuesta := p_transferencia.descripcionRespuesta;
      
       IF v_retorno.error = 'N' THEN      
         -- poblamos los datos a la variable de salida            
         p_boprog.cod_mon_credito := REPLACE(SUBSTR(TRIM(p_transferencia.monedaCuentaCredito), 1, 3), '.', '');
         p_boprog.monto           := p_transferencia.montoCredito;
         p_boprog.cod_mon_debito  := substr(p_transferencia.monedaCuentaDebito, 1, 3);
         p_boprog.cod_mon_credito := substr(p_transferencia.monedaCuentaCredito, 1, 3);
         p_boprog.nro_cta_debito  := substr(TRIM(p_transferencia.numeroCuentaDebito), 1, 15);
         p_boprog.nro_cta_credito := substr(TRIM(p_transferencia.numeroCuentaCredito), 1, 35);
         p_boprog.nom_cta_credito := substr(p_transferencia.nombre, 1, 100);
         p_boprog.cod_moneda      := p_boprog.cod_mon_credito;
                          
         -- obtenemos la oficina de la cuenta debito
         SELECT c.cod_oficina
           INTO p_boprog.cod_ofi_debito
           FROM ge_cuentas c
          WHERE c.nro_cuenta = p_boprog.nro_cta_debito;          
         -- cargamos los datos extras SNP
         v_extra := '<data>';
         v_extra := substr(v_extra || '<docType>'||p_data.tip_documento|| '</docType>', 1, 3000);
         v_extra := substr(v_extra || '<docNumber>'||p_data.nro_documento|| '</docNumber>', 1, 3000);
         v_extra := substr(v_extra || '<swift>'||p_data.cod_swift|| '</swift>', 1, 3000);
         v_extra := substr(v_extra || '<charge>'||p_data.cargos|| '</charge>', 1, 3000);
         v_extra := substr(v_extra || '<bankName>'||p_data.nom_banco|| '</bankName>', 1, 3000);
         v_extra := substr(v_extra || '</data>', 1, 3000);
         
         IF p_data.tip_documento IS NULL OR p_data.nro_documento IS NULL OR
            p_data.cod_swift IS NULL OR p_data.cargos IS NULL THEN
            v_retorno.error := 'S';
            v_retorno.nombreRespuesta := substr(MSG_ERROR, 1, 15);
            v_retorno.descripcionRespuesta := 'Campos snp faltantes';
         END IF;
         
         p_boprog.parametros := v_extra;          
      END IF;
       
      RETURN v_retorno;
   END;
   
   FUNCTION lf_val_dat_xml(p_sesion          IN VARCHAR2, 
                           p_cod_canal       IN VARCHAR2,
                           p_cod_tip_mensaje IN VARCHAR2,
                           p_xml             IN VARCHAR2,
                           p_boprog          OUT NOCOPY bw_ope_programadas%ROWTYPE) RETURN typ_mensajerespuesta IS
      v_transferencia     typ_transferenciaban;
      v_tra_interbancaria typ_transferenciainterbancaria;
      v_retorno           typ_mensajerespuesta := typ_mensajerespuesta;
      v_data              typ_xmlReader;
      v_fec_actual        DATE := pag_cal.fu_obt_fec_actual(9);
      v_estado            ge_snp_horarios.estado%TYPE;
   BEGIN
      -- obtenemos los datos
      lp_obt_dat_xml(p_cod_tip_mensaje, p_xml, v_data);
         
      -- validamos
      CASE p_cod_tip_mensaje
         WHEN '030' THEN -- transferencias propias
            v_transferencia := paw_bel.fu_transferenciasPropias(p_sesion,
                                                        p_cod_canal,
                                                        v_data.cta_debito,
                                                        v_data.monto,
                                                        v_data.cta_credito,
                                                        'P',  -- modo
                                                        NULL, -- concepto
                                                        NULL, -- cotizacion debito
                                                        NULL, --cotizacion credito
                                                        NULL, -- monto credito
                                                        NULL, -- CT
                                                        NULL  -- OTP
                                                        );
            
            -- poblamos los datos a p_boprog
            v_retorno := lf_obt_transferencia(v_transferencia, p_boprog);
         WHEN '036' THEN -- transferencias sipap
            --pas_snp.pr_ini_variables ;
            v_estado := pas_snp.fu_obt_est_horario( 103, '001', '002');
            IF v_estado = 'C' THEN
               v_fec_actual := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual+1,1,1); 
            END IF;
             
            v_tra_interbancaria := paw_bel.fu_transferenciaInterbancaria(p_sesion,
                                                                 p_cod_canal,
                                                                 'P',
                                                                 v_data.cod_swift,
                                                                 v_data.cta_credito,
                                                                 v_data.cta_debito,
                                                                 v_data.cod_moneda,
                                                                 v_data.monto,
                                                                 v_fec_actual,
                                                                 v_data.cargos,
                                                                 v_data.nro_documento,
                                                                 v_data.nom_beneficiario,
                                                                 v_data.dir_beneficiario,
                                                                 0,    -- numero contrato
                                                                 NULL, -- concepto
                                                                 NULL, -- ip
                                                                 v_data.tip_mensaje,
                                                                 v_data.tip_documento,
                                                                 NULL, -- numero referencia
                                                                 NULL, -- monto debito
                                                                 NULL, -- cotizacion debito
                                                                 NULL, -- cotizacion credito
                                                                 NULL, -- OTP
                                                                 NULL, -- CT
                                                                 NULL); --prioridad
            -- poblamos los datos a p_boprog
            v_retorno := lf_obt_tra_snp(v_tra_interbancaria, v_data, p_boprog);
         WHEN '039' THEN -- transferencias a terceros
            v_transferencia := paw_bel.fu_transferenciasTerceros(p_sesion,
                                                        p_cod_canal,
                                                        v_data.cta_debito,
                                                        v_data.monto,
                                                        v_data.cta_credito,
                                                        v_data.cod_moneda, --cod moneda credito
                                                        'P', -- modo
                                                        v_data.nro_documento,
                                                        NULL, -- concepto
                                                        NULL, -- contrato_prepacatado
                                                        NULL, -- CT
                                                        NULL  -- OTP
                                                        );
            -- poblamos los datos a p_boprog
            v_retorno := lf_obt_transferencia(v_transferencia, p_boprog);
            -- se agrega el numero de documento credito en el parametro
            p_boprog.parametros := '<data><docNumber>'||v_data.nro_documento|| '</docNumber></data>';
         ELSE
            paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END CASE;
      
      RETURN v_retorno;
   END;
   
   -- genera el movimiento de transferencia
   PROCEDURE lp_pro_transferencia(p_nro_programado  IN bw_ope_programadas_det.nro_referencia%TYPE,
                                  p_nro_detalle     IN bw_ope_programadas_det.nro_detalle%TYPE,
                                  p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                                  p_nro_caja        IN cj_cajas.nro_caja%TYPE,
                                  p_nro_cta_debito  IN ge_cuentas.nro_cuenta%TYPE,
                                  p_nro_cta_credito IN ge_cuentas.nro_cuenta%TYPE,
                                  p_cod_mon_debito  IN ba_monedas.cod_moneda%TYPE,
                                  p_cod_mon_credito IN ba_monedas.cod_moneda%TYPE,
                                  p_mto_debito      IN ge_movimientos.monto%TYPE,
                                  p_msj_error       OUT VARCHAR2) IS      
      v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
      v_cod_usuario     cj_cajas.cod_usuario%TYPE;
      v_cod_ofi_origen  cj_cajas.cod_oficina%TYPE;
      v_fec_ult_cierre  cj_cajas.fec_hor_cierre%TYPE;
      v_res_error       typ_mensajerespuesta;
      v_res_limite      paw_bel.typ_respuestaLimite;
      v_sesion          paw_bel.typ_validarSesion;
      v_horario         VARCHAR2(1);
      v_es_mov_noc      VARCHAR2(1);
      v_es_cta_noc      VARCHAR2(1);
      v_fec_actual      DATE;
      v_nro_operacion   ge_movimientos.nro_documento%TYPE;
      v_cod_tra_padre   ge_transacciones.cod_transaccion%TYPE := 388;
      v_mto_equ_local   ge_movimientos.mto_equ_local%TYPE;
      v_cotizacion      ge_movimientos.cotizacion%TYPE;
      v_mto_credito     ge_movimientos.monto%TYPE;
      v_cot_debito      ge_movimientos.cotizacion%TYPE;
      v_cot_credito     ge_movimientos.cotizacion%TYPE;
      v_concepto        ge_movimientos.concepto%TYPE;
      v_hor_actual      VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS');
      v_fec_valor       DATE := pag_cal.fu_obt_fec_actual(9);
      v_est_proceso     bw_ope_programadas.estado%TYPE;
      v_nvo_estado      ge_cuentas.estado%TYPE;
      v_sal_disponible  ge_cuentas.sal_contable%TYPE;
      v_procesa         VARCHAR2(1) := 'N';
   BEGIN
      -- confirmacion de operacion
      -- seteo las variables
      v_nro_secuencia := 0;
      p_msj_error := NULL;
      --
      -- obtengo datos de caja
      pr_obt_caja(p_nro_caja, v_cod_ofi_origen, v_cod_usuario, v_fec_ult_cierre);

      -- creamos punto de rollback
      prg_cre_savepoint(p_nro_programado||'-'||p_nro_detalle);
      --
      -- esta la cuenta en condiciones, verifico el horario
      v_res_error := paw_bel.fu_ver_horario(v_horario, 
                                            v_es_mov_noc, 
                                            v_es_cta_noc, 
                                            v_fec_ult_cierre, -- IN
                                            v_cod_ofi_origen, -- IN
                                            v_fec_actual);    
            
      IF v_res_error.error = 'N' then
         -- calculo la cotizacion
         IF p_cod_mon_credito <> p_cod_mon_debito THEN
            BEGIN
               paw_bel.pr_con_mon_a_moneda(p_cod_mon_debito, p_cod_mon_credito, p_mto_debito, v_mto_credito, v_cot_debito, v_cot_credito);
            EXCEPTION
               WHEN OTHERS THEN
                  p_msj_error := substr('Error de conversion de ' || p_cod_mon_debito || ' a ' || p_cod_mon_credito, 1, 1000);
            END;
         ELSE
            v_mto_credito := p_mto_debito;
         END IF;
         
         SELECT p.cod_persona, NULL
           INTO v_sesion.codigoPersona, v_sesion.codigoEmpresa
           FROM bw_ope_programadas p
          WHERE p.nro_referencia = p_nro_programado;         
         
         v_res_limite := paw_bel.fu_obtenerLimite(v_sesion,
                                                  p_cod_tip_mensaje, 
                                                  v_sesion.codigoPersona, 
                                                  p_nro_cta_debito, 
                                                  p_cod_mon_debito, 
                                                  503, 
                                                  v_cod_tra_padre,
                                                  p_mto_debito,
                                                  'C');
                                            
         IF v_res_limite.error = 'S' THEN
            p_msj_error := substr(v_res_limite.codRespuesta||'-'||v_res_limite.descripcionRespuesta, 1, 1000);           
         END IF;
         
         IF p_msj_error IS NULL THEN
            --
            -- seteo global
            pag_cta.PR_SET_VARIABLES(v_cod_usuario, v_fec_actual, v_cod_tra_padre, 'N', 'N', v_nro_secuencia, NULL, v_cod_ofi_origen, 9, 91);
            --
            v_mto_equ_local := NULL;
            v_cotizacion    := NULL;
            --
            -- verificamos las cotizaciones 
            IF p_cod_mon_debito <> g_cod_mon_local AND p_cod_mon_debito <> p_cod_mon_credito THEN            
               v_cotizacion := v_cot_debito;
               IF p_cod_mon_debito = g_cod_mon_local THEN
                  v_mto_equ_local := p_mto_debito;
               ELSE
                  v_mto_equ_local := round(v_cot_debito * p_mto_debito, 0);
               END IF;         
            END IF;
            --
            -- genero el numero de operacion
            SELECT s_nro_ope_homebanking.NEXTVAL
              INTO v_nro_operacion
              FROM dual;
            --
            -- se genera el debito
            IF p_cod_tip_mensaje = '039' THEN         
               v_concepto := substr('Transf. a ' || p_nro_cta_credito || ' desde ' || p_nro_cta_debito || ' programada ', 1, 100);
            ELSE
               v_concepto := substr('Transf. programada a ' || p_nro_cta_credito, 1, 100);
            END IF;
         
            --- Verificar si puede realizarse la operación sobre la cuenta de débito
            pag_cta.pr_ver_operacion(p_nro_cta_debito, v_cod_tra_padre, 9,
                                  91, 'D', p_cod_mon_debito,
                                  p_mto_debito, v_cod_ofi_origen,
                                  -- out
                                  pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_nvo_estado,
                                  v_sal_disponible, v_procesa, 503);

            IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
               p_msj_error := substr(v_procesa || ' - '||pag_cta.fu_obt_msj_error(), 1, 1000);            
            ELSE
               -- obtenemos la hora disponible
               v_hor_actual := fug_obt_hor_disponible(v_fec_valor, v_hor_actual, v_cod_usuario, v_es_mov_noc);
         
               pag_cta.PR_ACT_OPERACION(p_nro_cta_debito, v_hor_actual, 'D', 
                                      p_cod_mon_debito, p_mto_debito, v_cod_tra_padre, 
                                      503, v_nro_operacion, v_cotizacion, 
                                      v_cod_ofi_origen, 9, 91, 
                                      NULL, NULL, v_concepto, 
                                      'N', v_nro_secuencia, v_fec_valor, 
                                      NULL, NULL, v_mto_equ_local);
               
               IF nvl(pag_cta.g_cod_error, 0) = 0 THEN
                  v_cotizacion    := NULL;
                  v_mto_equ_local := NULL;
               
                  IF p_cod_mon_credito <> g_cod_mon_local AND p_cod_mon_debito <> p_cod_mon_credito THEN
                     v_cotizacion := v_cot_credito;
                     IF p_cod_mon_debito = g_cod_mon_local THEN
                        v_mto_equ_local := p_mto_debito;
                     END IF;
                  END IF;
                  -- seteo global
                  pag_cta.PR_SET_VARIABLES(v_cod_usuario, v_fec_actual, v_cod_tra_padre, 'N', 'N', v_nro_secuencia, NULL, v_cod_ofi_origen, 9, 91);
                  --
                  -- procesamos el credito
                  pag_cta.PR_ACT_OPERACION(p_nro_cta_credito, v_hor_actual, 'C', 
                                     p_cod_mon_credito, v_mto_credito, v_cod_tra_padre, 
                                     602, v_nro_operacion, v_cotizacion/*v_cot_credito*/, 
                                     v_cod_ofi_origen, 9, 91, 
                                     NULL, NULL, 'Transf. programada de ' || p_nro_cta_debito, 
                                     'N', v_nro_secuencia, v_fec_valor, 
                                     NULL, NULL, v_mto_equ_local);
                  
                  IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
                     p_msj_error := substr('Error al acreditar - ' ||pag_cta.fu_obt_msj_error, 1, 1000);
                  END IF;         
               ELSE
                  p_msj_error := substr('Error al debitar - ' ||pag_cta.fu_obt_msj_error, 1, 1000);
               END IF;
            END IF;
         END IF;         
      ELSE
         p_msj_error := substr(v_res_error.descripcionRespuesta, 1, 1000);
      END IF;
      
      IF p_msj_error IS NULL THEN
         v_est_proceso := 'C';
      ELSE
         v_est_proceso := 'A';
         prg_rol_savepoint(p_nro_programado||'-'||p_nro_detalle);
      END IF;    
                                
      -- actualizamos el estado del detalle
      pr_act_ope_detalle(p_nro_programado, p_nro_detalle, v_fec_valor, v_hor_actual, v_est_proceso, p_mto_debito, v_mto_credito, v_cot_debito, v_cot_credito, v_nro_operacion, p_msj_error);
   EXCEPTION
      WHEN OTHERS THEN
         p_msj_error := substr(SQLERRM, 1, 1000);
         prg_rol_savepoint(p_nro_programado||'-'||p_nro_detalle);
         pr_act_ope_detalle(p_nro_programado, p_nro_detalle, v_fec_valor, v_hor_actual, 'A', p_mto_debito, v_mto_credito, v_cot_debito, v_cot_credito, v_nro_operacion, p_msj_error);
   END;
   
   PROCEDURE lp_pro_tra_snp(p_nro_programado   IN bw_ope_programadas_det.nro_referencia%TYPE,
                            p_nro_detalle      IN bw_ope_programadas_det.nro_detalle%TYPE,
                            p_nro_caja         IN cj_cajas.nro_caja%TYPE,
                            p_cod_persona      IN ba_personas.cod_persona%TYPE,
                            p_nom_beneficiario IN bw_ope_programadas.nom_cta_credito%TYPE,
                            p_cod_ofi_debito   IN ba_oficinas.cod_oficina%TYPE,
                            p_nro_cta_debito   IN ge_cuentas.nro_cuenta%TYPE,
                            p_nro_cta_credito  IN ge_cuentas.nro_cuenta%TYPE,
                            p_cod_mon_debito   IN ba_monedas.cod_moneda%TYPE,
                            p_cod_mon_credito  IN ba_monedas.cod_moneda%TYPE,
                            p_mto_credito      IN ge_movimientos.monto%TYPE,
                            p_par_adicionales  IN bw_ope_programadas.parametros%TYPE,
                            p_msj_error        OUT VARCHAR2) IS      
      v_nro_secuencia           ge_movimientos.nro_secuencia%TYPE;
      v_cod_usuario             cj_cajas.cod_usuario%TYPE;
      v_cod_ofi_origen          cj_cajas.cod_oficina%TYPE;
      v_fec_ult_cierre          cj_cajas.fec_hor_cierre%TYPE;      
      v_mto_equ_local           ge_movimientos.mto_equ_local%TYPE;
      v_mto_debito              ge_movimientos.monto%TYPE;
      v_cot_debito              ge_movimientos.cotizacion%TYPE;
      v_cot_credito             ge_movimientos.cotizacion%TYPE;
      v_hor_actual              VARCHAR2(8) := to_char(SYSDATE, 'HH24:MI:SS');      
      v_fec_actual              DATE := pag_cal.fu_obt_fec_actual(9);
      v_fec_valor               DATE := v_fec_actual;
      r_gtran                   pas_snp.rg_msj;
      v_cod_swift               VARCHAR2(20) ;
      v_nro_doc_credito         ba_personas.nro_documento%TYPE := NULL;  -- nro de documento del acreditado      
      v_cargos                  VARCHAR2(1);
      v_cod_swi_pte_solicitante ge_snp_transferencias.cod_swi_pte_solicitante%TYPE;
      v_dir_beneficiario        ge_snp_transferencias.dir_beneficiario%TYPE;
      v_tip_doc_beneficiario    ge_snp_transferencias.cod_tip_doc_beneficiario%TYPE;
      v_mto_credito             ge_snp_transferencias.monto%TYPE;
      v_tip_cargos              ge_snp_transferencias.tip_cargo%TYPE;
      v_estado                  ge_snp_transferencias.estado%TYPE := 'N' ; -- Estado del Periodo SNP
      v_cta_pte_solicitante     ge_snp_transferencias.nro_cta_pte_solicitante%TYPE; -- Nro de Cuenta Interbancaria
      v_cta_pte_sol_bcp         ge_snp_transferencias.nro_cta_solicitante%TYPE;
      v_tip_movimiento          VARCHAR2(1) ; -- D:Débito; C: Crédito
      v_msj_swift               ge_snp_transferencias.msj_swift%TYPE;
      v_cod_mod_padre           ge_transacciones.cod_modulo%TYPE;             -- Modulo Padre
      v_cod_mad_padre           ge_transacciones.cod_modalidad%TYPE;          -- Modalidad Padre      
      v_cod_tra_padre           ge_transacciones.cod_transaccion%TYPE := 303; -- cod. transaccion padre
      v_cod_tra_credito         ge_transacciones.cod_transaccion%TYPE := 196; -- cod. transaccion hijo credito
      v_cod_tra_debito          ge_transacciones.cod_transaccion%TYPE := 503; -- cod. transaccion hijo debito      
      v_nro_referencia          ge_snp_transferencias.nro_referencia%TYPE;
      v_xml                     xmltype;
      v_res_error               typ_mensajerespuesta;
      v_res_limite              paw_bel.typ_respuestaLimite;
      v_sesion                  paw_bel.typ_validarSesion; 
      v_horario                 VARCHAR2(1);
      v_es_mov_noc              VARCHAR2(1);
      v_es_cta_noc              VARCHAR2(1);
      v_est_proceso             bw_ope_programadas_det.estado%TYPE;
      v_cli_pue_enviar          varchar2(1);
      v_cod_mon_local           ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
   BEGIN
      -- confirmacion de operacion
      -- seteo las variables
      v_nro_secuencia := 0;
      p_msj_error := NULL;
      --
      -- obtengo datos de caja
      pr_obt_caja(p_nro_caja, v_cod_ofi_origen, v_cod_usuario, v_fec_ult_cierre);
      
      -- creamos punto de rollback
      prg_cre_savepoint(p_nro_programado||'-'||p_nro_detalle);

      --
      -- esta la cuenta en condiciones, verifico el horario
      v_res_error := paw_bel.fu_ver_horario(v_horario, 
                                                v_es_mov_noc, 
                                                v_es_cta_noc, 
                                                v_fec_ult_cierre, -- IN
                                                v_cod_ofi_origen, -- IN
                                                v_fec_actual);
      IF v_res_error.error = 'S' THEN
         p_msj_error := substr(v_res_error.descripcionRespuesta, 1, 1000);
         GOTO end_tag;
      END IF;
      v_mto_credito := p_mto_credito;
      IF p_cod_mon_credito <> p_cod_mon_debito THEN
         BEGIN
            paw_bel.pr_con_mon_a_moneda(p_cod_mon_credito,
                                            p_cod_mon_debito,
                                            v_mto_credito,
                                            v_mto_debito,
                                            v_cot_credito,
                                            v_cot_debito,
                                            'S');
         EXCEPTION
            WHEN OTHERS THEN
               p_msj_error := substr('Error de conversion de ' || p_cod_mon_debito || ' a ' || p_cod_mon_credito, 1, 1000);
               GOTO end_tag;
         END;
      ELSE
         v_mto_debito := v_mto_credito;
      END IF;
      
      SELECT p.cod_persona, NULL
        INTO v_sesion.codigoPersona, v_sesion.codigoEmpresa
        FROM bw_ope_programadas p
       WHERE p.nro_referencia = p_nro_programado;  
       
      v_res_limite := paw_bel.fu_obtenerLimite(v_sesion,
                                               '036', 
                                               v_sesion.codigoPersona, 
                                               p_nro_cta_debito, 
                                               p_cod_mon_debito, 
                                               503, 
                                               v_cod_tra_padre,
                                               v_mto_debito,
                                               'C');
      IF v_res_limite.error = 'S' THEN
         p_msj_error := substr(v_res_limite.codRespuesta||'-'||v_res_limite.descripcionRespuesta, 1, 1000);
         GOTO end_tag;
      END IF;
                                                  
      v_xml := xmltype.createxml(p_par_adicionales);
      
      --v_dir_beneficiario := substr(TRIM(v_xml.extract('/data/address/text()').getStringVal()), 1, 100);
      v_cargos := substr(TRIM(v_xml.extract('/data/charge/text()').getStringVal()), 1, 1);
      v_nro_doc_credito := substr(TRIM(v_xml.extract('/data/docNumber/text()').getStringVal()), 1, 20);
      v_tip_doc_beneficiario := v_xml.extract('/data/docType/text()').getNUmberVal();
      v_cod_swift := substr(TRIM(v_xml.extract('/data/swift/text()').getStringVal()), 1, 20);
       
      IF v_cargos = 'O' THEN
         v_tip_cargos := 'OUR';
      ELSIF v_cargos = 'B' then
         v_tip_cargos := 'BEN';
      ELSE
         v_tip_cargos := 'SHA';
      END IF;
      
      pas_snp.pr_ini_variables;
      pas_snp.pr_ini_registros;
      
      v_cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
      v_cta_pte_sol_bcp         :=  pas_snp.fu_obt_cta_ban_participante(v_cod_swi_pte_solicitante, p_cod_mon_credito);
      v_cta_pte_solicitante     :=  pas_snp.fu_obt_cta_bancaria(v_cta_pte_sol_bcp ,'C');
      -- Se graba la operacion como solicitado y pendiente de autorización
      v_nro_referencia                 := pas_snp.fu_obt_sig_nro_referencia(v_fec_actual);
      r_gtran.fec_valor                := v_fec_valor ;
      r_gtran.cod_msj_swift            := 103; 
      r_gtran.nro_cta_solicitante      := p_nro_cta_debito ;
      r_gtran.nro_cta_pte_solicitante  := v_cta_pte_sol_bcp;
      r_gtran.nro_cta_beneficiario     := p_nro_cta_credito ;
      r_gtran.cod_swi_pte_beneficiario := v_cod_swift; 
      r_gtran.cod_moneda               := p_cod_mon_credito;
      r_gtran.monto                    := v_mto_credito ;
      r_gtran.nro_referencia           := v_nro_referencia;
      r_gtran.cod_modulo               := 4;
      r_gtran.cod_modalidad            := 455 ;
      r_gtran.cod_oficina              := p_cod_ofi_debito;
      r_gtran.cod_tip_operacion        := '001';
      r_gtran.cod_sub_tip_operacion    := '002';
      r_gtran.fec_ingreso              := v_fec_actual ;
      r_gtran.cod_per_solicitante      := p_cod_persona;
      r_gtran.nom_solicitante          := fue_obt_nom_persona(p_cod_persona) ;
      r_gtran.dir_solicitante          := fue_obt_dir_principa(p_cod_persona) ;
      r_gtran.cod_tip_doc_solicitante  := fue_obt_doc_principal(p_cod_persona) ; 
      r_gtran.nro_doc_solicitante      := fue_obt_nro_doc_persona(p_cod_persona) ;
      r_gtran.cod_swi_pte_solicitante  := v_cod_swi_pte_solicitante;
      r_gtran.nom_beneficiario         := p_nom_beneficiario;
      r_gtran.dir_beneficiario         := v_dir_beneficiario;
      r_gtran.cod_tip_doc_beneficiario := v_tip_doc_beneficiario;
      r_gtran.nro_doc_beneficiario     := v_nro_doc_credito;
      r_gtran.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(v_cod_swift, p_cod_mon_credito) ;
      r_gtran.observacion              := 'Operacion Programada';
      r_gtran.tip_cargo                := v_tip_cargos;
      r_gtran.ind_valor                := 'S';
      r_gtran.situacion                := 'P' ; -- Pendiente de Envio a BCP
      r_gtran.estado                   := 'S' ; -- Solicitado
      r_gtran.prioridad                := 20 ;
      r_gtran.nro_operacion            := v_nro_referencia ;
      r_gtran.tip_mensaje              := 'CRED';
      r_gtran.ben_dir_correo           := NULL;
      
       --- MTOP Jun/2020 operaciones sipap generados fuera de horario van como MT102
      --if v_modo in ('V', 'C', 'A', 'P') THEN
      v_cli_pue_enviar := fug_pue_env_tra_fue_hora(r_gtran.cod_msj_swift,r_gtran.cod_tip_operacion,r_gtran.cod_sub_tip_operacion,v_cod_tra_padre,r_gtran.monto, r_gtran.cod_moneda, r_gtran.fec_valor, p_nro_cta_debito);
      if paw_bas.fu_obt_tip_TransfInterbancaria(r_gtran.cod_msj_swift,r_gtran.cod_tip_operacion,r_gtran.cod_sub_tip_operacion,v_cod_tra_padre,r_gtran.monto, r_gtran.cod_moneda, r_gtran.fec_valor, fug_obt_cli_principal(p_nro_cta_debito)) ='103' then
         r_gtran.ind_valor := 'S';
         r_gtran.cod_msj_swift := 103;
         r_gtran.cod_tip_operacion := '001';
         r_gtran.cod_sub_tip_operacion := '002';
         if ((fug_den_per_act_snp(r_gtran.cod_msj_swift,r_gtran.cod_tip_operacion,r_gtran.cod_sub_tip_operacion,v_cod_tra_padre,3) = 'S') and
             (p_cod_mon_credito = v_cod_mon_local) and 
             (p_cod_mon_debito <> v_cod_mon_local) and 
             (v_cli_pue_enviar = 'S'))
             then       
             r_gtran.ind_valor := 'N';
             r_gtran.cod_msj_swift := 102;
             r_gtran.cod_tip_operacion := '011';
             r_gtran.cod_sub_tip_operacion := '001';
         end if;
      else
         r_gtran.ind_valor := 'N';
         r_gtran.cod_msj_swift := 102;
         r_gtran.cod_tip_operacion := '011';
         r_gtran.cod_sub_tip_operacion := '001';
      end if;

      --end if;
      ---      
      -- se inserta el registro
      
      r_gtran.fec_valor := paw_bas.fu_obt_snp_fec_acreditacion(r_gtran.cod_msj_swift, r_gtran.cod_moneda);
      pas_snp.pr_ins_transferencias(r_gtran) ;
      -- verificamos si no hubo error
      IF nvl(pas_snp.fu_obt_cod_error,1) <> 0 THEN         
         p_msj_error := substr(pas_snp.fu_obt_msj_error, 1, 1000);
         GOTO end_tag;
      END IF;
      -- verificamos el horario SNP     
      v_estado := pas_snp.fu_obt_est_horario(r_gtran.cod_msj_swift,
                                             r_gtran.cod_tip_operacion,
                                             r_gtran.cod_sub_tip_operacion);
      if ((v_estado = 'A') and
          (fug_den_per_act_snp(r_gtran.cod_msj_swift,r_gtran.cod_tip_operacion,r_gtran.cod_sub_tip_operacion,v_cod_tra_padre,3) = 'S') and
          (v_cli_pue_enviar <> 'S')) then
           v_estado := 'C';
      end if;      
      
      IF v_fec_valor = v_fec_actual THEN
         --v_estado := pas_snp.fu_obt_est_horario(r_gtran.cod_msj_swift,
         --                                       r_gtran.cod_tip_operacion,
         --                                       r_gtran.cod_sub_tip_operacion);
         --if ((v_estado = 'A') and
         --    (fug_den_per_act_snp(r_gtran.cod_msj_swift,r_gtran.cod_tip_operacion,r_gtran.cod_sub_tip_operacion,v_cod_tra_padre,3) = 'S') and
         --    (v_cli_pue_enviar <> 'S')) then
         --     v_estado := 'C';
         --end if;  
         IF v_estado NOT IN ('C', 'A') THEN
            p_msj_error := substr('Estado invalido: ['||v_estado||']' || pas_snp.fu_obt_msj_error, 1, 1000);
            GOTO end_tag;
         END IF;
      END IF;
      --
      -- Genera el Mensaje Swift solo si es 103, para 102 solo cambiamos de estado
      if r_gtran.cod_msj_swift = 103 then
          v_msj_swift := pas_snp.fu_obt_msj_mt103(v_nro_referencia, 'N') ;
          --
          -- Actualiza el Estado y le agrega el Mensaje Swift generado
          UPDATE ge_snp_transferencias gt
             SET gt.msj_swift = v_msj_swift,
                 gt.estado = 'A'
           WHERE gt.nro_referencia = v_nro_referencia
             AND gt.cod_msj_swift = r_gtran.cod_msj_swift;
          -- control de actualizacion
          IF SQL%NOTFOUND THEN
             p_msj_error := 'Nro de Referencia Transf. exterior invalida '||v_nro_referencia;
             GOTO end_tag;
          END IF;
          --   
      else
           -- Actualiza el Estado 
          UPDATE ge_snp_transferencias gt
             SET gt.estado = 'A'
           WHERE gt.nro_referencia = v_nro_referencia
             AND gt.cod_msj_swift = r_gtran.cod_msj_swift;       
      end if;       
      --
      
      -- se hace el debito, sino esta abierto se deja como autorizado para que 
      -- se envie a BCP en la apertura del horario SNP
      --IF v_estado = 'A' THEN
         -- se retornara la transacción a ser utilizada para la generación del movimiento.
        -- Genera el Movimiento y envia el mensaje a BCP si la fecha es actual y esta activo
      IF r_gtran.ind_valor = 'S' and  -- alto valor
         r_gtran.cod_msj_swift = 103 THEN   
         pas_snp.pr_obt_par_mensajes( 103,    -- Tipo MT
                                      '001',  -- Tipo de Operación
                                      '002',  -- Sub-Tipo de Operación
                                      'E',    -- Transferencia Enviada
                                      v_cod_mod_padre,
                                      v_cod_mad_padre,
                                      v_cod_tra_credito
                                      --,v_cod_tra_padre
                                      );  -- CNFPRSIP-217 --
         IF p_cod_mon_debito <> g_cod_mon_local THEN
            IF p_cod_mon_credito = g_cod_mon_local THEN
               v_mto_equ_local := v_mto_credito ;
            ELSE
               v_mto_equ_local := null ;
            END IF;
         END IF;
         -- obtenemos la hora disponible
         v_hor_actual := fug_obt_hor_disponible(v_fec_valor, v_hor_actual, v_cod_usuario, v_es_mov_noc);
         -- seteo global
         pag_cta.pr_set_variables(v_cod_usuario, v_fec_valor, v_cod_tra_padre, 'N', 'N', v_nro_secuencia);
         pag_cta.pr_set_nro_documento3(NULL);
         -- Registrar movimientos de Debito al CLIENTE
         prg_ver_mod_horario;
         pag_cta.pr_act_operacion(p_nro_cta_debito ,     -- Nro.Cta.
                                  v_hor_actual,          -- Hora
                                  'D',                   -- Tip.Mov.
                                   p_cod_mon_debito,      -- Cod.Mon.
                                   v_mto_debito,          -- Monto
                                   v_cod_tra_padre,       -- Trx.Padre
                                   v_cod_tra_debito,      -- Trx.Hija
                                   v_nro_referencia,      -- Nro.Doc.
                                   v_cot_debito,          -- Cotizacion
                                   p_cod_ofi_debito,      -- Ofic.Orig.
                                   v_cod_mod_padre,       -- Mod.Pad.Cliente
                                   v_cod_mad_padre,       -- Mad.Pad.Cliente
                                   NULL,                  -- Cod.Tasa
                                   NULL,                  -- Val.Tasa
                                   'HB-SNP-Transf.Cta. '||p_nro_cta_credito/*v_cta_pte_solicitante*/|| ' Programada',
                                   'S',                   -- Emit.Aviso
                                   v_nro_secuencia,
                                   v_fec_actual,
                                   null,   -- Cod_Banco
                                   null,   -- Cod_Causa
                                   v_mto_equ_local);
         -- controlamos el debito
         IF nvl(pag_cta.fu_obt_cod_error,1) <> 0 THEN
            p_msj_error := substr(pag_cta.fu_obt_msj_error, 1, 1000);
            GOTO end_tag;
         ELSE
            IF p_cod_mon_credito <> g_cod_mon_local THEN
               IF p_cod_mon_debito = g_cod_mon_local THEN
                  v_mto_equ_local := v_mto_debito ;
               ELSE
                  v_mto_equ_local := null ;
               END IF;
            END IF;
            -- obtenemos el tipo de movimiento contraparte
            v_tip_movimiento := pas_snp.fu_obt_tip_mov_transaccion(v_cod_mod_padre,v_cod_mad_padre,v_cod_tra_credito) ;
            IF nvl(pas_snp.fu_obt_cod_error,1) <> 0 THEN
               p_msj_error := substr(pas_snp.fu_obt_msj_error, 1, 1000);
               GOTO end_tag;
            ELSE
               -- seteo global
               pag_cta.pr_set_variables(v_cod_usuario, v_fec_valor, v_cod_tra_padre, 'N', 'N', v_nro_secuencia);
               -- Setea el Tipo de Movimiento del Rubro para SNP
               pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(v_cta_pte_solicitante), v_tip_movimiento);
               -- Setea la Referencia del Movimiento para SNP
               pag_cta.pr_set_referencia(v_cod_swift) ;
               -- Registrar movimientos a la Cta. Interbancaria
               prg_ver_mod_horario;
               pag_cta.pr_act_operacion(v_cta_pte_solicitante, -- Nro.Cta.
                                        v_hor_actual,          -- Hora
                                        v_tip_movimiento,      -- Tip.Mov.
                                        p_cod_mon_credito,     -- Cod.Mon.
                                        v_mto_credito,         -- Monto
                                        v_cod_tra_padre,       -- Trx.Padre
                                        v_cod_tra_credito,     -- Trx.Hija
                                        v_nro_referencia,      -- Nro.Doc.
                                        v_cot_credito,         -- Cotizacion
                                        p_cod_ofi_debito,      -- Ofic.Orig.
                                        v_cod_mod_padre,       -- Mod.Pad.Cliente
                                        v_cod_mad_padre,       -- Mad.Pad.Cliente
                                        NULL,                  -- Cod.Tasa
                                        NULL,                  -- Val.Tasa
                                        'HB-SNP-Transf.Cta. '||p_nro_cta_debito||' programado',
                                        'S',                   -- Emit.Aviso
                                        v_nro_secuencia,
                                        v_fec_actual,
                                        null,   -- Cod_Banco
                                        null,   -- Cod_Causa
                                        v_mto_equ_local );
               -- controlamos el movimiento contraparte                          
               IF pag_cta.fu_obt_cod_error = 0 THEN
                  pas_snp.pr_gen_mov_cargo(r_gtran,
                                           p_nro_cta_debito,
                                           v_cta_pte_solicitante,
                                           v_mto_credito,
                                           v_hor_actual,
                                           v_nro_secuencia
                                           --,'W'
                                           );
               END IF;
               
               -- limpiamos los parametros
               pag_cta.pr_set_cod_rubro(NULL, v_tip_movimiento);
               -- Setea la Referencia del Movimiento para SNP
               pag_cta.pr_set_referencia(NULL);

               IF nvl(pag_cta.fu_obt_cod_error,1) <> 0 THEN
                  p_msj_error := substr(pag_cta.fu_obt_msj_error, 1, 1000);
                  GOTO end_tag;
               ELSE
                  BEGIN
                     -- Actualiza la Transferencia
                     UPDATE ge_snp_transferencias gt
                        SET gt.fecha       = v_fec_actual,
                            gt.hora        = v_hor_actual,
                            gt.cod_usuario = v_cod_usuario
                      WHERE gt.nro_referencia = v_nro_referencia
                        AND gt.cod_msj_swift = 103;
   
                     IF SQL%NOTFOUND THEN
                        p_msj_error := 'Confirmacion SNP invalida ' ||v_nro_referencia;
                        GOTO end_tag;
                     END IF;
                     --GENERAR MOVIMIENTO DE POSICIÓN DE CAMBIOS
                     paw_bel.pr_act_mov_ope_cambios(v_hor_actual, v_nro_referencia, p_cod_mon_debito, p_cod_mon_credito, v_cod_usuario);
                  END;
               END IF;
            END IF;
         END IF;
      END IF;
      
      <<end_tag>>
      IF p_msj_error IS NULL THEN
         v_est_proceso := 'C';
         -- si llego hasta aca no hubo errores
         --COMMIT; 
         -- Si esta todo OK envia la transferencia al Socket
         IF v_estado = 'A' THEN
            pas_snp.pr_gen_arc_swift(v_nro_referencia, 'N');
         END IF;
      ELSE
         v_est_proceso := 'A';
         prg_rol_savepoint(p_nro_programado||'-'||p_nro_detalle);         
      END IF;
                                
      -- actualizamos el estado del detalle
      pr_act_ope_detalle(p_nro_programado, p_nro_detalle, v_fec_valor, v_hor_actual, v_est_proceso, v_mto_debito, v_mto_credito, v_cot_debito, v_cot_credito, v_nro_referencia, p_msj_error);
   EXCEPTION
      WHEN OTHERS THEN
         p_msj_error := substr(SQLERRM, 1, 1000);
         prg_rol_savepoint(p_nro_programado||'-'||p_nro_detalle);
         pr_act_ope_detalle(p_nro_programado, p_nro_detalle, v_fec_valor, v_hor_actual, 'A', v_mto_debito, v_mto_credito, v_cot_debito, v_cot_credito, v_nro_referencia, p_msj_error);
   END;   

   -- finaliza la operacion programada
   PROCEDURE pr_act_ope_detalle(p_nro_referencia IN bw_ope_programadas_det.nro_referencia%TYPE,
                                p_nro_detalle    IN bw_ope_programadas_det.nro_detalle%TYPE,
                                p_fecha          IN bw_ope_programadas_det.fecha%TYPE,
                                p_hora           IN bw_ope_programadas_det.hora%TYPE,
                                p_estado         IN bw_ope_programadas_det.estado%TYPE,
                                p_mto_debito     IN bw_ope_programadas_det.mto_debito%TYPE,
                                p_mto_credito    IN bw_ope_programadas_det.mto_credito%TYPE,
                                p_cotizacion     IN bw_ope_programadas_det.cotizacion%TYPE,
                                p_cot_contra     IN bw_ope_programadas_det.cot_contra%TYPE,
                                p_nro_documento  IN bw_ope_programadas_det.nro_documento%TYPE,
                                p_msj_error      IN bw_ope_programadas_det.observacion%TYPE) IS  
      --PRAGMA AUTONOMOUS_TRANSACTION; 
      --v_total  NUMBER;
   BEGIN
      UPDATE bw_ope_programadas_det d
         SET d.estado = p_estado, d.observacion = substr(p_msj_error, 1, 1000),
             d.mto_debito = p_mto_debito, d.mto_credito = p_mto_credito,
             d.cotizacion = p_cotizacion, d.cot_contra = p_cot_contra,
             d.nro_documento = p_nro_documento, d.fecha = p_fecha,
             d.hora = p_hora             
       WHERE d.nro_referencia = p_nro_referencia         
         AND d.nro_detalle = p_nro_detalle;
      --COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         lp_reg_error('pr_act_ope_detalle['||p_nro_referencia||'-'||p_nro_detalle||']', SQLERRM);      
   END;

   -- finaliza la operacion programada
   PROCEDURE pr_fin_operacion(p_nro_referencia IN bw_ope_programadas.nro_referencia%TYPE) IS
   BEGIN
      UPDATE bw_ope_programadas p
         SET p.estado = 'C'
       WHERE p.nro_referencia = p_nro_referencia
         AND p.estado = 'V';
   END;
   -- procedimiento que procesa los detalles pendientes del dia   
   PROCEDURE pr_pro_debitos IS
      rg_bopro        bw_ope_programadas%ROWTYPE;
      v_msj_error     bw_ope_programadas_det.observacion%TYPE;
      CURSOR c_detalles IS
         SELECT d.nro_referencia, d.nro_detalle
           FROM bw_ope_programadas_det d
          WHERE d.fec_programada <= pag_cal.fu_obt_fec_actual(9)
            AND d.estado = 'P';
   BEGIN
      FOR det IN c_detalles LOOP
         BEGIN
            -- cargamos la cabecera
            SELECT * 
              INTO rg_bopro
              FROM bw_ope_programadas p 
             WHERE p.nro_referencia = det.nro_referencia;
             
            v_msj_error := NULL;
            -- se procesa el movimiento
            CASE rg_bopro.cod_tip_mensaje
               WHEN '030' THEN                                  
                  lp_pro_transferencia(det.nro_referencia,
                                       det.nro_detalle,
                                       rg_bopro.cod_tip_mensaje,
                                       rg_bopro.nro_caja, 
                                       rg_bopro.nro_cta_debito, 
                                       rg_bopro.nro_cta_credito,
                                       rg_bopro.cod_mon_debito,
                                       rg_bopro.cod_mon_credito,
                                       rg_bopro.monto,
                                       v_msj_error);
               WHEN '036' THEN
                  lp_pro_tra_snp(det.nro_referencia,
                                 det.nro_detalle,
                                 rg_bopro.nro_caja, 
                                 rg_bopro.cod_persona,
                                 rg_bopro.nom_cta_credito,
                                 rg_bopro.cod_ofi_debito,
                                 rg_bopro.nro_cta_debito, 
                                 rg_bopro.nro_cta_credito,
                                 rg_bopro.cod_mon_debito,
                                 rg_bopro.cod_mon_credito,
                                 rg_bopro.monto,
                                 rg_bopro.parametros,
                                 v_msj_error);
               WHEN '039' THEN
                  lp_pro_transferencia(det.nro_referencia,
                                       det.nro_detalle,
                                       rg_bopro.cod_tip_mensaje,
                                       rg_bopro.nro_caja, 
                                       rg_bopro.nro_cta_debito, 
                                       rg_bopro.nro_cta_credito,
                                       rg_bopro.cod_mon_debito,
                                       rg_bopro.cod_mon_credito,
                                       rg_bopro.monto,
                                       v_msj_error);
               ELSE
                  NULL;
            END CASE;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END LOOP;      
   END;
      
   FUNCTION fu_obt_cantidad(p_frecuencia IN bw_ope_programadas.frecuencia%TYPE) RETURN NUMBER IS
      v_cantidad NUMBER;
   BEGIN
      CASE p_frecuencia
         WHEN 'D' THEN v_cantidad := 1; -- diaria
         WHEN 'S' THEN v_cantidad := 7; -- semanal
         WHEN 'Q' THEN v_cantidad := 15; -- quincenal
         WHEN 'M' THEN v_cantidad := 30; -- mensual
         WHEN 'B' THEN v_cantidad := 60; -- bimensual
         WHEN 'T' THEN v_cantidad := 90; -- trimestral
         ELSE v_cantidad := 0;          
      END CASE;
      
      RETURN v_cantidad;
   END;
   
   FUNCTION fu_obt_nombre(p_frecuencia IN bw_ope_programadas.frecuencia%TYPE) RETURN VARCHAR2 IS
      v_nombre VARCHAR2(100);
   BEGIN
      CASE p_frecuencia
         WHEN 'U' THEN v_nombre := 'Unica';
         WHEN 'D' THEN v_nombre := 'Diaria';
         WHEN 'S' THEN v_nombre := 'Semanal';
         WHEN 'Q' THEN v_nombre := 'Quincenal';
         WHEN 'M' THEN v_nombre := 'Mensual';
         WHEN 'B' THEN v_nombre := 'Bimensual';
         WHEN 'T' THEN v_nombre := 'Trimensual';
         ELSE v_nombre := 'Frecuencia desconocida';
      END CASE;
      
      RETURN v_nombre;
   END;
   
   FUNCTION fu_obt_fec_siguiente(p_frecuencia IN bw_ope_programadas.frecuencia%TYPE,
                                 p_fecha      IN bw_ope_programadas.fec_sig_operacion%TYPE,
                                 p_cantidad   IN bw_ope_programadas.can_operaciones%TYPE DEFAULT NULL) RETURN DATE IS
      v_retorno  DATE;
      v_cantidad NUMBER;
      v_fecha_siguiente DATE;
   BEGIN
      
      v_cantidad := fu_obt_cantidad(p_frecuencia) * nvl(p_cantidad, 1);
      v_fecha_siguiente := p_fecha + v_cantidad;
      IF to_number(to_char(p_fecha,'MM')) <> to_number(to_char(v_fecha_siguiente,'MM')) THEN 
			   v_cantidad := v_cantidad;
      ELSE
			   v_cantidad := v_cantidad + 1;
      END IF;
      v_retorno := pag_cal.FU_OBT_FEC_HABIL(p_fecha + v_cantidad, 1, NULL);
      RETURN v_retorno;
   END;
   
   -- obtiene el monto total programada de una fecha
   FUNCTION fu_obt_pro_limite(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                              p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                              p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                              p_fecha           IN bw_ope_programadas.fec_sig_operacion%TYPE) RETURN NUMBER IS
      v_monto ge_movimientos.monto%TYPE := 0;
   BEGIN
      SELECT nvl(SUM(d.monto), 0)
        INTO v_monto
        FROM bw_ope_programadas d
       WHERE d.cod_persona = p_cod_persona
         AND d.estado = 'V'
         AND d.cod_tip_mensaje = p_cod_tip_mensaje
         AND d.cod_moneda = p_cod_moneda
         AND trunc(d.fec_sig_operacion) = trunc(p_fecha);
      RETURN v_monto;
   END;
   
   -- obtiene la cantidad total programada de una fecha
   FUNCTION fu_obt_pro_cantidad(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                                p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                                p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                                p_fecha           IN bw_ope_programadas.fec_sig_operacion%TYPE) RETURN NUMBER IS
      v_cantidad NUMBER := 0;
   BEGIN
      SELECT nvl(COUNT(d.monto), 0)
        INTO v_cantidad
        FROM bw_ope_programadas d
       WHERE d.cod_persona = p_cod_persona
         AND d.estado = 'V'
         AND d.cod_tip_mensaje = p_cod_tip_mensaje
         AND trunc(d.fec_sig_operacion) = trunc(p_fecha);
      RETURN v_cantidad;
   END;
   
   -- obtiene los limites maximos de monto y cantidad de una persona
   PROCEDURE pr_obt_max_limite(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                               p_tip_persona     IN ba_personas.tipo%TYPE,
                               p_cod_tip_mensaje IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                               p_cod_moneda      IN ba_monedas.cod_moneda%TYPE,
                               p_mto_maximo      OUT bw_cla_lim_montos.mto_maximo%TYPE,
                               p_can_maxima      OUT bw_cla_lim_cantidades.can_maxima%TYPE
                              ) IS      
   BEGIN      
      p_mto_maximo := -99;
      p_can_maxima := -99;
      
      -- cargamos el monto maximo establecido
      BEGIN
         SELECT MAX(m.mto_maximo)
           INTO p_mto_maximo
           FROM bw_cla_lim_montos m
          WHERE m.cod_tip_mensaje = p_cod_tip_mensaje
            AND m.activo = 'A'
            AND m.cod_moneda = p_cod_moneda
            AND m.tip_persona = p_tip_persona
            AND m.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            SELECT MAX(m.mto_maximo)
              INTO p_mto_maximo
              FROM bw_cla_lim_montos m
             WHERE m.cod_tip_mensaje = p_cod_tip_mensaje
               AND m.activo = 'A'
               AND m.cod_moneda = p_cod_moneda
               AND m.tip_persona = p_tip_persona
               AND m.cod_persona IS NULL;
      END;
      -- cargamos la cantidad maxima establecida
      BEGIN
         SELECT c.can_maxima
           INTO p_can_maxima
           FROM bw_cla_lim_cantidades c
          WHERE c.cod_tip_mensaje = p_cod_tip_mensaje
            AND c.estado = 'S'
            AND c.tip_persona = p_tip_persona
            AND c.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            SELECT c.can_maxima
              INTO p_can_maxima
              FROM bw_cla_lim_cantidades c
             WHERE c.cod_tip_mensaje = p_cod_tip_mensaje
               AND c.tip_persona = p_tip_persona
               AND c.estado = 'S'
               AND c.cod_persona IS NULL;
      END;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   
   /*
   G: operacion registrada por el usuario
   R: operacion cancelada por el usuario
   C: operacion confirmada por el sistema
   A: operacion anulada por el sistema
   S: operacion proxima a ser ejecutada
   */
   FUNCTION lf_notificacion(p_ope_programada IN bw_ope_programadas%ROWTYPE,
                            p_operacion      IN VARCHAR2) RETURN NUMBER IS
      v_cabecera   VARCHAR2(700)  := NULL;
      v_detalle    VARCHAR2(3500) := NULL;
      v_pie        VARCHAR2(350)  := NULL;
      v_tag        VARCHAR2(50);
      v_dir_correo ba_mails.dir_correo%TYPE;
      v_number     NUMBER;
   BEGIN
      -- obtenemos la direccion de correo de la cuenta debito
      v_dir_correo := paw_seg.fu_obt_mail(fug_obt_cli_principal(p_ope_programada.nro_cta_debito));
      -- controlamos el envio de correo
      IF nvl(fug_ind_produccion, 'N') = 'N' AND nvl(v_dir_correo, 'x') <> fug_obt_pardinamico('TST_NOT_MAIL') THEN
         RETURN -1;
      END IF;           
      -- ---------- cabecera --------------
      v_cabecera := 
            -- inicio div
            fu_not_inicio ||
            -- titulo
            fu_not_titulo('OPERACIONES PROGRAMADAS');
            
            -- subtitulo
            IF p_operacion = 'G' THEN
               v_tag := ' de registro';
               v_cabecera := v_cabecera ||
               fu_not_titulo2('REGISTRADA');
            ELSIF p_operacion = 'R' THEN
               v_tag := ' de anulacion';
               v_cabecera := v_cabecera ||
               fu_not_titulo_err('ANULADA');
            ELSIF p_operacion = 'A' THEN
               v_tag := ' de rechazo';
               v_cabecera := v_cabecera ||
               fu_not_titulo_err('RECHAZADA');
            ELSIF p_operacion = 'C' THEN
               v_tag := ' de operacion';
               v_cabecera := v_cabecera ||
               fu_not_titulo2('CONFIRMADA');
            ELSIF p_operacion = 'S' THEN
               v_tag := ' a procesar';
               v_cabecera := v_cabecera ||
               fu_not_titulo2(utl_url.escape('AVISO DE DÉBITO', TRUE, 'UTF-8'));            
            END IF;
            
      v_cabecera := v_cabecera ||
            -- inicio tabla
            fu_not_ini_tabla || 
            -- inicio tbody
            fu_not_ini_tab_cuerpo;
   
      -- ---------- pie --------------
      -- fin tabla, fin div
      v_pie := 
            -- fin tbody
            fu_not_fin_tab_cuerpo || 
            -- fin table
            fu_not_fin_tabla;
            
      -- detalles      
      IF p_operacion <> 'S' THEN
         v_detalle :=              fu_not_row_tag('Fecha '||v_tag, to_char(sysdate, 'dd/mm/yyyy'));
         v_detalle := v_detalle || fu_not_row_tag('Hora '||v_tag, to_char(sysdate, 'hh24:mi:ss'));
      ELSE
         v_detalle :=              fu_not_row_tag('Fecha '||v_tag, to_char(p_ope_programada.fec_sig_operacion, 'dd/mm/yyyy'));
      END IF;
      v_detalle := v_detalle || fu_not_row_tag('Nro. Operacion', p_ope_programada.nro_referencia);
      v_detalle := v_detalle || fu_not_row_tag('Tipo de Operacion', fue_obt_des_operacion(p_ope_programada.cod_tip_mensaje));      
      v_detalle := v_detalle || fu_not_row_tag('Cuenta de debito', p_ope_programada.nro_cta_debito);
      v_detalle := v_detalle || fu_not_row_tag('Denominacion de cuenta debito', fug_obt_nom_cuenta(p_ope_programada.nro_cta_debito));
      v_detalle := v_detalle || fu_not_row_tag('Moneda cuenta debito', fue_obt_des_moneda(p_ope_programada.cod_mon_debito));
      v_detalle := v_detalle || fu_not_row_tag('Cuenta de credito', p_ope_programada.nro_cta_credito);
      v_detalle := v_detalle || fu_not_row_tag('Beneficiario', utl_url.escape(p_ope_programada.nom_cta_credito, TRUE, 'UTF-8'));
      v_detalle := v_detalle || fu_not_row_tag('Moneda cuenta credito', fue_obt_des_moneda(p_ope_programada.cod_mon_credito));
      v_detalle := v_detalle || fu_not_row_tag('Concepto/Alias', utl_url.escape(p_ope_programada.concepto, TRUE, 'UTF-8'));
      IF p_ope_programada.cod_moneda <> pag_gen.fu_obt_mon_local() THEN
         v_detalle := v_detalle || fu_not_row_tag('Monto de la operacion', p_ope_programada.cod_moneda|| ' ' ||to_char(p_ope_programada.monto, '999G999G999G999G999D99'));
      ELSE
         v_detalle := v_detalle || fu_not_row_tag('Monto de la operacion', p_ope_programada.cod_moneda|| ' ' ||to_char(p_ope_programada.monto, '999G999G999G999G999'));
      END IF;
      IF p_operacion IN ('G', 'R') THEN
         v_detalle := v_detalle || fu_not_row_tag('Frecuencia', fu_obt_nombre(p_ope_programada.frecuencia));
         v_detalle := v_detalle || fu_not_row_tag('Fecha de inicio', to_char(p_ope_programada.fec_inicio, 'dd/mm/yyyy'));

         -- datos solo al registrar una operacion
         IF p_operacion = 'G' THEN
            IF p_ope_programada.fec_fin_plazo IS NOT NULL THEN
               v_detalle := v_detalle || fu_not_row_tag('Fecha de finalizacion', to_char(p_ope_programada.fec_fin_plazo, 'dd/mm/yyyy'));
            ELSIF p_ope_programada.can_operaciones IS NOT NULL THEN
               v_detalle := v_detalle || fu_not_row_tag('Cantidad', p_ope_programada.can_operaciones); 
            ELSE 
               v_detalle := v_detalle || fu_not_row_tag('Fecha de finalizacion', 'Sin Vencimiento'); 
            END IF;
         END IF;
         
      END IF;
      IF p_operacion = 'R' THEN
         v_detalle := v_detalle || fu_not_row_tag('Operaciones ejecutadas', p_ope_programada.can_ope_realizadas);
      END IF;
      
      IF p_operacion = 'S' THEN
         v_pie := v_pie || fu_not_sub_titulo2(utl_url.escape('Estimado Cliente: si desea cancelar dicha operación, diríjase a la sección "Gestionar Operaciones Programadas" en el Home Banking.', TRUE, 'UTF-8'));
      END IF;
      
      -- fin div
      v_pie := v_pie || fu_not_fin;      
      v_number := paw_not.fu_env_email_prueba(v_dir_correo, v_cabecera || v_detalle || v_pie, 'paw_pro');
      RETURN v_number;
   EXCEPTION
      WHEN OTHERS THEN
         lp_reg_error('paw_pro.lf_notificacion#operacion:'||p_operacion||'#referencia:'||p_ope_programada.nro_referencia, sqlerrm);      
         RETURN -99;
   END;

   -- Validacion y confirmacion de programacion de operaciones  
   FUNCTION fu_programarOperacion(p_sesion         IN VARCHAR2,
                                  p_codigoCanal    IN VARCHAR2,
                                  p_modo           IN VARCHAR2,
                                  p_codigoMensaje  IN VARCHAR2,
                                  p_operacion      IN VARCHAR2,
                                  p_frecuencia     IN VARCHAR2, 
                                  p_fechaInicio    IN DATE,
                                  p_fechaFin       IN DATE,
                                  p_cantidad       IN NUMBER,
                                  p_concepto       IN VARCHAR2,
                                  p_referencia     IN NUMBER,
                                  p_xmlData        IN VARCHAR2,
                                  p_claveToken     IN VARCHAR2) RETURN typ_opeProgramada IS
      v_retorno           typ_opeProgramada := typ_opeProgramada;
      v_msj_respuesta     typ_mensajerespuesta := typ_mensajerespuesta;
      
      v_modo              VARCHAR2(1);
      v_cod_operacion     VARCHAR2(3) := '105';
      v_frecuencia        VARCHAR2(1);
      v_operacion         VARCHAR2(1);
      v_fec_final         bw_ope_programadas.fec_fin_plazo%TYPE;
      v_concepto          bw_ope_programadas.concepto%TYPE;
      v_usu_sesion        paw_bel.typ_validarSesion;
      v_msj_bitacora      VARCHAR2(700);
      v_existe            VARCHAR2(1);
      rg_boprog           bw_ope_programadas%ROWTYPE  := NULL;
      v_mto_programado    bw_ope_programadas.monto%TYPE;
      v_can_programada    bw_ope_programadas.can_operaciones%TYPE;
      v_tip_persona       ba_personas.tipo%TYPE;
      v_mto_maximo        bw_cla_lim_montos.mto_maximo%TYPE;
      v_can_maxima        bw_cla_lim_cantidades.can_maxima%TYPE;
      v_cantidad          bw_ope_programadas.can_operaciones%TYPE;
      v_cod_tip_operacion bw_tip_mensajes.cod_tip_mensaje%TYPE;
      v_mto_debito        ge_movimientos.monto%TYPE;
      v_tip_notificacion  VARCHAR2(1);
      v_max_dias          NUMBER := 730;
      v_number            NUMBER;
   BEGIN
      paw_bel.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);    
      
      -- validamos la sesion del user
      v_msj_respuesta := paw_bel.fu_validarActividad(p_sesion, p_codigoCanal);      
      IF v_msj_respuesta.error = 'S' THEN
         v_retorno.error := 'S';
         v_retorno.nombreRespuesta := v_msj_respuesta.nombreRespuesta;
         v_retorno.descripcionRespuesta := v_msj_respuesta.descripcionRespuesta;
         RETURN v_retorno;
      ELSE
         pr_obt_dat_sesion(p_sesion, v_usu_sesion);         
      END IF;
      
      v_modo         := substr(TRIM(p_modo), 1, 1);
      v_frecuencia   := substr(TRIM(p_frecuencia), 1, 1);
      v_operacion    := substr(TRIM(p_operacion), 1, 1);
      v_concepto     := paw_bel.depurarTextos(p_concepto, 60);
      v_cod_tip_operacion := substr(TRIM(p_codigoMensaje), 1, 3);
      v_msj_bitacora := substr('modo:'||v_modo
                                      ||', fre: '||v_frecuencia
                                      ||', ope: '||v_operacion
                                      ||', fec_ini: '||to_char(p_fechaInicio, 'dd/mm/yyyy')
                                      ||', fec_fin: '||p_fechaFin
                                      ||', tip_ope:' || v_cod_tip_operacion
                                      ||', can: '||p_cantidad
                                      ||', ref: '||p_referencia, 1, 700);
      paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ENTRADA);  
      
      IF v_modo NOT IN ('V', 'C') THEN
         v_msj_bitacora := v_msj_bitacora || ', modo invalido';
         paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
         RETURN v_retorno; 
      END IF;  
            
      IF p_operacion = 'G' THEN
         -- validamos la frecuencia
         IF v_frecuencia NOT IN ('U', 'D', 'S', 'Q', 'M', 'B', 'T') THEN
            v_msj_bitacora := v_msj_bitacora || ', frecuencia invalida';
            paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;
         IF v_concepto IS NULL THEN
            v_msj_bitacora := v_msj_bitacora || ', concepto no recibido';
            paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;
         IF p_fechaInicio IS NULL THEN
            v_msj_bitacora := v_msj_bitacora || ', fecha inicio no recibida';
            paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;
         -- validamos fecha inicio
         IF p_fechaInicio > TRUNC(SYSDATE + 30) THEN
            v_msj_bitacora := v_msj_bitacora || ', fec ini > 30 dias';
            paw_bel.pr_mensajeUsuario('FEC_PAG_EXCEDID', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;
         -- validamos parametros de fechas
         IF p_fechaInicio > nvl(p_fechaFin, p_fechaInicio) THEN
            v_msj_bitacora := v_msj_bitacora || ', fec ini > fec fin';
            paw_bel.pr_mensajeUsuario('RANGOFEC_INVAL', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;
         -- validamos que la fecha inicio no sea hoy
         IF trunc(SYSDATE) >= trunc(p_fechaInicio) THEN
            v_msj_bitacora := v_msj_bitacora || ', fec ini > hoy';
            paw_bel.pr_mensajeUsuario('FECHA_INVA', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno;
         END IF;
         -- validamos que la fecha inicio sea habil
         IF pag_cal.fu_obt_fec_habil(p_fechaInicio, 1, NULL) != p_fechaInicio THEN
            v_msj_bitacora := v_msj_bitacora || ', fec ini';
            paw_bel.pr_mensajeUsuario('FEC_NOHABIL', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno;
         END IF;
         -- validamos que la fecha fin sea habil (si se recibe)
         IF p_fechaFin IS NOT NULL AND pag_cal.fu_obt_fec_habil(p_fechaFin, 1, NULL) != p_fechaFin THEN
            v_msj_bitacora := v_msj_bitacora || ', fec fin';
            paw_bel.pr_mensajeUsuario('FEC_NOHABIL', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno;
         END IF;         
         -- validamos la cantidad de operaciones
         IF nvl(p_cantidad, 0) > 999 THEN
            paw_bel.pr_mensajeUsuario('G_CAN_EXCED', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;         
         -- validamos cantidad con frecuencia
         IF (nvl(p_cantidad, 0) > 1 AND v_frecuencia = 'U') OR nvl(p_cantidad, 0) < 0 THEN
            v_msj_bitacora := v_msj_bitacora || ', cant. con frec.';
            paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno;
         END IF;              
         -- si la frecuencia es unica, la fecha fin es la fecha inicio
         IF v_frecuencia = 'U' THEN
            v_fec_final := TRUNC(p_fechaInicio);
            v_cantidad := NULL;
         ELSE
            v_fec_final := TRUNC(p_fechaFin);
            v_cantidad := p_cantidad;
         END IF;      
         -- se debe especificar fecha fin o cantidad (excluyente)
         IF v_fec_final IS NOT NULL AND p_cantidad IS NOT NULL THEN
            v_msj_bitacora := v_msj_bitacora || ', o fec o can';
            paw_bel.pr_mensajeUsuario('G_PRO_FEC_CAN', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;
         -- validamos que sea una programacion con vencimiento
         IF v_fec_final IS NULL AND v_cantidad IS NULL THEN
            v_msj_bitacora := v_msj_bitacora || ' sin venc.';
            paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;
         -- validamos que la fecha fin no sea superior a dos años
         IF nvl(v_fec_final, TRUNC(SYSDATE)) - p_fechaInicio > 730 THEN
            v_msj_bitacora := v_msj_bitacora || 'fec. fin 730 dias';
            paw_bel.pr_mensajeUsuario('FEC_PAG_EXCEDID', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;
         -- obtenemos los dias por frecuencia
         v_can_programada := fu_obt_cantidad(p_frecuencia); 
         IF v_can_programada = 0 THEN
            v_can_programada := v_max_dias;
         END IF;
         -- maxima cantidad de dias permitido por frecuencia
         -- para frecuencia diaria, si no se quiere superar dos años
         -- no se deben contar los dias no habiles
         SELECT decode(v_frecuencia, 'D', 504, 730)
           INTO v_max_dias
           FROM DUAL;
         -- validamos que la fecha fin no sea superior a dos años
         IF nvl(v_cantidad, 0) > v_max_dias / v_can_programada  THEN
            v_msj_bitacora := v_msj_bitacora || 'can. mayor a '|| v_max_dias || ' / ' || v_can_programada;
            paw_bel.pr_mensajeUsuario('FEC_PAG_EXCEDID', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno; 
         END IF;
         -- validamos los datos y carga el row para insertar en bw_ope_programadas
         v_msj_respuesta := lf_val_dat_xml(p_sesion, p_codigoCanal, v_cod_tip_operacion, p_xmlData, rg_boprog);
         -- si hay error retornamos
         IF v_msj_respuesta.error = 'S' THEN
            v_retorno.error := 'S';
            v_retorno.nombreRespuesta := v_msj_respuesta.nombreRespuesta;
            v_retorno.descripcionRespuesta := v_msj_respuesta.descripcionRespuesta;
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_ERROR);
            RETURN v_retorno;
         END IF;
         -- cargamos los datos
         rg_boprog.cod_tip_mensaje    := v_cod_tip_operacion;
         rg_boprog.cod_persona        := nvl(v_usu_sesion.codigoEmpresa, v_usu_sesion.codigoPersona);
         rg_boprog.concepto           := v_concepto;
         rg_boprog.frecuencia         := v_frecuencia;
         rg_boprog.fec_inicio         := TRUNC(p_fechaInicio);
         rg_boprog.fec_fin_plazo      := v_fec_final;
         rg_boprog.can_operaciones    := v_cantidad;
         rg_boprog.can_ope_realizadas := 0;
         rg_boprog.estado             := 'V';
         rg_boprog.nro_caja           := p_codigoCanal;
         rg_boprog.fec_sig_operacion  := TRUNC(p_fechaInicio);
      ELSIF p_operacion = 'C' THEN -- cancelar la programacion
         BEGIN
            SELECT * 
              INTO rg_boprog
              FROM bw_ope_programadas 
             WHERE nro_referencia = p_referencia
               AND estado = 'V'
               AND cod_persona = nvl(v_usu_sesion.codigoEmpresa, v_usu_sesion.codigoPersona);
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_msj_bitacora := substr(v_msj_bitacora || ', ORA: [' || SQLERRM || ']', 1, 700);
               paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
               RETURN v_retorno;
         END;
      ELSE
         v_msj_bitacora := v_msj_bitacora || ', tipo operacion invalida';
         paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
         RETURN v_retorno;
      END IF;
      
      IF v_operacion = 'G' THEN
         -- validacion de limites
         -- obtenemos el monto total programado de una fecha
         v_mto_programado := fu_obt_pro_limite(rg_boprog.cod_persona,
                                               rg_boprog.cod_tip_mensaje,
                                               rg_boprog.cod_mon_debito,
                                               rg_boprog.fec_inicio);
                                              
         -- obtenemos la cantidad total programada de una fecha                
         v_can_programada := fu_obt_pro_cantidad(rg_boprog.cod_persona,
                                                 rg_boprog.cod_tip_mensaje,
                                                 rg_boprog.cod_mon_debito,
                                                 rg_boprog.fec_inicio);
         SELECT decode(v_usu_sesion.codigoEmpresa, NULL, 'F', 'J')
           INTO v_tip_persona
           FROM DUAL;
           
         pr_obt_max_limite(rg_boprog.cod_persona,
                           v_tip_persona,
                           rg_boprog.cod_tip_mensaje,
                           rg_boprog.cod_mon_debito,
                           v_mto_maximo,
                           v_can_maxima);
                           
         IF rg_boprog.cod_mon_debito <> rg_boprog.cod_mon_credito AND rg_boprog.cod_tip_mensaje = '036' THEN
            -- operaciones sipap estan definidas por la moneda credito, por lo que el monto debito 
            -- se debe calcular
            DECLARE
               v_cot_credito ge_movimientos.cotizacion%TYPE;
               v_cot_debito  ge_movimientos.cotizacion%TYPE;
            BEGIN
               paw_bel.pr_con_mon_a_moneda(rg_boprog.cod_mon_credito, -- moneda original
                                           rg_boprog.cod_mon_debito,  -- moneda a convertir
                                           rg_boprog.monto,           -- monto original
                                           v_mto_debito,              -- monto a convertir
                                           v_cot_credito,             -- cotizacion original
                                           v_cot_debito,              -- cotizacion a convertir
                                           'S');
            EXCEPTION
               WHEN OTHERS THEN
                  paw_bel.pr_mensajeUsuario('TRA_ERR_CONVERS', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            END;
         ELSE
            v_mto_debito := rg_boprog.monto;            
         END IF;
         v_msj_bitacora := v_msj_bitacora || ', mto_pro:' || v_mto_programado 
                                          || ', mto_deb:' || v_mto_debito 
                                          || ', can_pro:' || v_can_programada 
                                          || ', mto_max:' || v_mto_maximo 
                                          || ', can_max:' || v_can_maxima;
         IF v_mto_maximo = -99 THEN -- limite de monto no definido
            paw_bel.pr_mensajeUsuario('G_COD_LIM_INDEF', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         ELSIF v_can_maxima = -99 THEN -- limite de cantidad no definido
            paw_bel.pr_mensajeUsuario('G_LIM_CAN_INDEF', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         ELSIF v_mto_maximo < (v_mto_programado + v_mto_debito) THEN -- monto limite superado
            paw_bel.pr_mensajeUsuario('G_COD_LIM_EXCED', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         ELSIF v_can_maxima < (v_can_programada + 1) THEN -- cantidad limite superada
            paw_bel.pr_mensajeUsuario('G_LIM_CAN_EXCED', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         END IF;
        
         -- salimos por error
         IF v_retorno.error = 'S' THEN
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_ERROR);
            RETURN v_retorno;
         END IF;
        
         -- validamos que no sea recien generada la programacion
         DECLARE
            v_min_transaccion NUMBER := nvl(to_number(fug_obt_pardinamico('PAW_MIN_TRANSACCION')), 10);               
         BEGIN            
            SELECT 'S'
              INTO v_existe
              FROM bw_ope_programadas p
             WHERE p.monto = rg_boprog.monto
               AND p.nro_cta_debito = rg_boprog.nro_cta_debito
               AND p.nro_cta_credito = rg_boprog.nro_cta_credito
               AND p.cod_persona = nvl(v_usu_sesion.codigoEmpresa, v_usu_sesion.codigoPersona)
               AND p.cod_tip_mensaje = rg_boprog.cod_tip_mensaje
               AND trunc(p.fec_inicio) = trunc(rg_boprog.fec_inicio)
               AND p.cod_moneda = rg_boprog.cod_moneda
               AND p.estado = 'V'
               AND p.nro_caja = p_codigoCanal
               AND nvl(p.fec_fin_plazo, trunc(sysdate)) = nvl(rg_boprog.fec_fin_plazo, trunc(sysdate))
               AND ((SYSDATE) - fec_insercion) * 1440 <= v_min_transaccion
               AND rownum = 1;

         EXCEPTION               
            WHEN OTHERS THEN
               v_existe := 'N';
         END;

            
         IF v_existe = 'S' THEN
            paw_bel.pr_mensajeUsuario('G_MOV_YA_INGRE', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
            RETURN v_retorno;
         END IF;
      END IF;
      
      -- controlar la clave OTP, modo V: envio de challenge, modo C: control de OTP
      v_msj_respuesta := paw_bel.fu_validarOTP(p_claveToken, v_usu_sesion.codigoPersona, v_usu_sesion.codigoEmpresa, v_modo);
      -- si hay error retornamos
      IF v_msj_respuesta.error = 'S' THEN
         v_retorno.error := 'S';
         v_retorno.nombreRespuesta := v_msj_respuesta.nombreRespuesta;
         v_retorno.descripcionRespuesta := v_msj_respuesta.descripcionRespuesta;
         paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_ERROR);
         RETURN v_retorno;
      END IF;
      
      IF v_modo = 'C' THEN
         IF v_operacion = 'G' THEN           
            
            SELECT s_ope_programadas.nextval 
              INTO rg_boprog.nro_referencia
              FROM DUAL;        

            -- se insertan los datos faltantes
            INSERT INTO bw_ope_programadas VALUES rg_boprog;
            
            -- se inserta el detalle
            v_retorno.numeroReferencia := rg_boprog.nro_referencia;
         ELSIF v_operacion = 'C' THEN
            -- se anula operacion programada
            UPDATE bw_ope_programadas p
               SET p.fec_anulacion = SYSDATE,
                   p.estado = 'A'
             WHERE p.nro_referencia = p_referencia
               AND p.cod_persona = nvl(v_usu_sesion.codigoEmpresa, v_usu_sesion.codigoPersona)
               AND p.estado = 'V';
            -- para control
            IF SQL%ROWCOUNT > 1 THEN
               paw_bel.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||', eli:' ||SQL%ROWCOUNT||' '||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_ERROR);
               RETURN v_retorno;
            END IF;
            -- se anula el detalle pendiente
            UPDATE bw_ope_programadas_det d
               SET d.estado = 'A',
                   d.observacion = 'Cancelado por usuario'
             WHERE d.nro_referencia = p_referencia
               AND d.estado = 'P';
         END IF;
      END IF;
      
      v_retorno.numeroReferencia    := rg_boprog.nro_referencia;
      v_retorno.frecuencia          := rg_boprog.frecuencia;
      v_retorno.fechaInicio         := rg_boprog.fec_inicio;
      v_retorno.fechaFin            := rg_boprog.fec_fin_plazo;
      v_retorno.fechaSiguiente      := rg_boprog.fec_sig_operacion;
      v_retorno.fechaAnulacion      := rg_boprog.fec_anulacion;
      v_retorno.estado              := rg_boprog.estado;
      v_retorno.concepto            := rg_boprog.concepto;
      v_retorno.monedaOperacion     := rg_boprog.cod_moneda;
      v_retorno.montoOperacion      := rg_boprog.monto;
      v_retorno.cuentaDebito        := rg_boprog.nro_cta_debito;
      v_retorno.cuentaCredito       := rg_boprog.nro_cta_credito;
      v_retorno.nombreCuentaCredito := rg_boprog.nom_cta_credito;
      v_retorno.cantidadProgramada  := rg_boprog.can_operaciones;
      v_retorno.cantidadRealizada   := rg_boprog.can_ope_realizadas;
      v_retorno.monedaDebito        := rg_boprog.cod_mon_debito;
      v_retorno.monedaCredito       := rg_boprog.cod_mon_credito;
      v_retorno.tipoOperacion       := substr(fue_obt_des_operacion(rg_boprog.cod_tip_mensaje), 1, 100);    
      
      IF v_modo = 'C' AND v_retorno.error = 'N' THEN
         -- notificacion de la operacion registrada
         IF v_operacion = 'C' THEN
            v_tip_notificacion := 'R';
         ELSE
            v_tip_notificacion := v_operacion;
         END IF;
         v_number := lf_notificacion(rg_boprog, v_tip_notificacion);
         v_msj_bitacora := v_msj_bitacora || ', res_mail: ' || v_number;
      END IF;
      
      paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora||' ' ||paw_bel.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_SALIDA);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_bel.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || '] ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_ERROR);
         RETURN v_retorno;
   END;
   
   -- generar el detalle a partir de la cabecera programada
   PROCEDURE lp_car_detalles(p_nro_referencia  IN bw_ope_programadas.nro_referencia%TYPE,
                             p_cod_tip_mensaje IN bw_ope_programadas.cod_tip_mensaje%TYPE,
                             p_fec_programada  IN bw_ope_programadas.fec_sig_operacion%TYPE,
                             p_nro_detalle     IN bw_ope_programadas.can_operaciones%TYPE,
                             p_cod_mon_debito  IN bw_ope_programadas.cod_mon_debito%TYPE,
                             p_cod_mon_credito IN bw_ope_programadas.cod_mon_credito%TYPE,
                             p_monto           IN bw_ope_programadas.monto%TYPE,
                             p_pro_detalles    OUT NOCOPY bw_ope_programadas_det%ROWTYPE) IS
   BEGIN
      p_pro_detalles.nro_referencia := p_nro_referencia;
      p_pro_detalles.nro_detalle    := p_nro_detalle + 1;
      p_pro_detalles.estado         := 'P';
      p_pro_detalles.fec_programada := p_fec_programada;      
      
      IF p_cod_mon_debito = p_cod_mon_credito THEN
         p_pro_detalles.mto_debito  := p_monto;
         p_pro_detalles.mto_credito := p_monto;
      ELSE
         IF p_cod_tip_mensaje = '036' THEN
            p_pro_detalles.mto_credito := p_monto;
            -- monto debito se calcula en el dia de la operacion
         ELSE
            p_pro_detalles.mto_debito := p_monto;
         END IF;
         
         IF p_cod_mon_debito = pag_gen.FU_OBT_MON_LOCAL THEN
            p_pro_detalles.cotizacion := 1;
         END IF;
         
         IF p_cod_mon_credito = pag_gen.FU_OBT_MON_LOCAL THEN
            p_pro_detalles.cot_contra := 1;
         END IF;
      END IF;
   END;
   
   PROCEDURE lp_act_fec_siguiente(p_nro_referencia IN bw_ope_programadas.nro_referencia%TYPE,
                                  p_fec_siguiente  IN bw_ope_programadas.fec_sig_operacion%TYPE) IS      
   BEGIN
      UPDATE bw_ope_programadas p
         SET p.fec_sig_operacion = p_fec_siguiente,
             p.can_ope_realizadas = p.can_ope_realizadas + 1
       WHERE p.nro_referencia = p_nro_referencia
         AND p.estado = 'V';
   END;
      
   -- inserta la fecha siguiente de la operacion programada
   PROCEDURE pr_ins_ope_siguiente(p_nro_referencia  IN bw_ope_programadas.nro_referencia%TYPE,
                                  p_cod_tip_mensaje IN bw_ope_programadas.cod_tip_mensaje%TYPE,
                                  p_fec_programada  IN bw_ope_programadas.fec_sig_operacion%TYPE,
                                  p_nro_detalle     IN bw_ope_programadas.can_operaciones%TYPE,
                                  p_cod_mon_debito  IN bw_ope_programadas.cod_mon_debito%TYPE,
                                  p_cod_mon_credito IN bw_ope_programadas.cod_mon_credito%TYPE,
                                  p_monto           IN bw_ope_programadas.monto%TYPE) IS
      rg_bopdet bw_ope_programadas_det%ROWTYPE;
   BEGIN     
      rg_bopdet.nro_referencia := p_nro_referencia;
      rg_bopdet.nro_detalle    := p_nro_detalle + 1;
      rg_bopdet.estado         := 'P';
      rg_bopdet.fec_programada := p_fec_programada;
      rg_bopdet.est_comprobante := 'P';
      
      IF p_cod_mon_debito = p_cod_mon_credito THEN
         rg_bopdet.mto_debito  := p_monto;
         rg_bopdet.mto_credito := p_monto;
      ELSE
         IF p_cod_tip_mensaje = '036' THEN
            rg_bopdet.mto_credito := p_monto;
            -- monto debito se calcula en el dia de la operacion
         ELSE
            rg_bopdet.mto_debito := p_monto;
         END IF;
         
         IF p_cod_mon_debito = pag_gen.FU_OBT_MON_LOCAL THEN
            rg_bopdet.cotizacion := 1;
         END IF;
         
         IF p_cod_mon_credito = pag_gen.FU_OBT_MON_LOCAL THEN
            rg_bopdet.cot_contra := 1;
         END IF;
      END IF;

      -- se inserta el detalle
      INSERT INTO bw_ope_programadas_det VALUES rg_bopdet;
   END;
   
   -- procedimiento para generar las operaciones a realizar
   PROCEDURE pr_gen_programadas IS
      CURSOR c_programados IS
         SELECT p.nro_referencia, p.cod_tip_mensaje, p.fec_sig_operacion,
                p.can_ope_realizadas, p.cod_mon_debito, p.cod_mon_credito,
                p.monto, p.frecuencia
           FROM bw_ope_programadas p
          WHERE p.fec_sig_operacion <= pag_cal.fu_obt_fec_actual(9)
            AND p.estado = 'V';
      v_fec_siguiente DATE;
   BEGIN
      FOR cu IN c_programados LOOP
         -- inserta el nuevo detalle
         pr_ins_ope_siguiente( cu.nro_referencia, cu.cod_tip_mensaje,
                               cu.fec_sig_operacion, cu.can_ope_realizadas,
                               cu.cod_mon_debito, cu.cod_mon_credito,
                               cu.monto );
         v_fec_siguiente := fu_obt_fec_siguiente(cu.frecuencia, cu.fec_sig_operacion);
         lp_act_fec_siguiente(cu.nro_referencia, v_fec_siguiente);
      END LOOP;
   END;
   
   -- procedimiento para cancelar las operaciones programadas
   PROCEDURE pr_can_ope_programadas IS
      CURSOR c_operaciones IS
         SELECT nro_referencia
           FROM bw_ope_programadas a        
          WHERE estado = 'V'
            AND 
            (
               (fec_fin_plazo IS NOT NULL AND 
                  /*fec_sig_operacion >= fec_fin_plazo AND*/ fec_fin_plazo <= pag_cal.fu_obt_fec_actual(9)
               ) OR
               (fec_fin_plazo IS NULL AND can_operaciones IS NOT NULL AND can_ope_realizadas >= can_operaciones)
            );
   BEGIN
      FOR c in c_operaciones LOOP
         pr_fin_operacion(c.nro_referencia);
      END LOOP;
   END;
   
   -- listar las operaciones programadas
   FUNCTION fu_obtenerProgramados(p_sesion      IN VARCHAR2,
                                  p_codigoCanal IN VARCHAR2,
                                  p_estado      IN VARCHAR2 DEFAULT NULL,
                                  p_fechaInicio IN DATE DEFAULT NULL,
                                  p_fechaFin    IN DATE DEFAULT NULL,
                                  p_concepto    IN VARCHAR2 DEFAULT NULL) RETURN typ_programadas IS
      v_retorno       typ_programadas := typ_programadas();
      v_lista         typ_listaprogramadas := typ_listaprogramadas();
      v_programado    typ_opeprogramada := typ_opeprogramada();
      v_msj_respuesta typ_mensajerespuesta := typ_mensajerespuesta();
      v_usu_sesion    paw_bel.typ_validarSesion;
      v_fec_inicial   bw_ope_programadas.fec_inicio%TYPE;
      v_fec_final     bw_ope_programadas.fec_inicio%TYPE;
      v_estado        bw_ope_programadas.estado%TYPE;
      v_concepto      bw_ope_programadas.concepto%TYPE;
      v_cod_persona   bw_ope_programadas.cod_persona%TYPE;
      v_cantidad      NUMBER := 0;
      v_cod_operacion VARCHAR2(3) := '105';
      v_msj_bitacora  VARCHAR2(700);
      CURSOR c_operaciones IS
         SELECT * 
           FROM bw_ope_programadas p
          WHERE p.cod_persona = v_cod_persona
            AND p.estado = nvl(v_estado, p.estado)
            AND 
              (
                 (p.fec_inicio BETWEEN v_fec_inicial AND v_fec_final AND v_fec_inicial IS NOT NULL AND v_fec_final IS NOT NULL) 
                  OR v_fec_inicial IS NULL OR v_fec_final IS NULL
              )
            AND lower(p.concepto) LIKE '%'||lower(nvl(v_concepto, p.concepto)) ||'%'
          ORDER BY p.estado DESC, fec_sig_operacion;
   BEGIN
      paw_bel.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);    
      
      -- validamos la sesion del user
      v_msj_respuesta := paw_bel.fu_validarActividad(p_sesion, p_codigoCanal);      
      IF v_msj_respuesta.error = 'S' THEN
         v_retorno.error := 'S';
         v_retorno.nombreRespuesta := v_msj_respuesta.nombreRespuesta;
         v_retorno.descripcionRespuesta := v_msj_respuesta.descripcionRespuesta;
         RETURN v_retorno;
      ELSE
         pr_obt_dat_sesion(p_sesion, v_usu_sesion);         
      END IF;
      
      v_cod_persona := nvl(v_usu_sesion.codigoEmpresa, v_usu_sesion.codigoPersona);
      v_estado      := TRIM(substr(p_estado, 1, 1));
      v_concepto    := paw_bel.depurarTextos(p_concepto, 60);
      v_fec_inicial := p_fechaInicio;
      v_fec_final   := p_fechaFin;
      
      v_msj_bitacora := substr('lista - est:' || v_estado||
                               'fec_ini: '||v_fec_inicial||
                               'fec_fin: '||v_fec_final||
                               'con:'||v_concepto, 1, 700);
                               
      paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_ENTRADA);
      
      FOR c IN c_operaciones LOOP
         v_programado.numeroReferencia := c.nro_referencia;
         v_programado.frecuencia := c.frecuencia;
         v_programado.fechaInicio := c.fec_inicio;
         v_programado.fechaFin    := c.fec_fin_plazo;
         v_programado.fechaAnulacion := c.fec_anulacion;
         v_programado.fechaSiguiente := c.fec_sig_operacion;
         v_programado.estado         := c.estado;
         v_programado.concepto       := c.concepto;        
         v_programado.monedaOperacion := c.cod_moneda;
         v_programado.montoOperacion := c.monto;
         v_programado.cuentaDebito := c.nro_cta_debito;
         v_programado.cuentaCredito := c.nro_cta_credito;
         v_programado.nombreCuentaCredito := c.nom_cta_credito;
         v_programado.cantidadProgramada := c.can_operaciones;
         v_programado.cantidadRealizada := c.can_ope_realizadas;
         v_programado.monedaDebito   := c.cod_mon_debito;
         v_programado.monedaCredito  := c.cod_mon_credito;
         v_programado.tipoOperacion  := substr(fue_obt_des_operacion(c.cod_tip_mensaje), 1, 100); 
         v_programado.fechaInsercion   := c.fec_insercion;
         
         v_lista.extend;
         v_lista(v_lista.count) := v_programado;
         v_cantidad := v_cantidad + 1;
      END LOOP;
      v_retorno.cantidad := v_cantidad;
      v_retorno.listaDetalles := v_lista;
      
      paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ', can: ' || v_cantidad || ' ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_SALIDA);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_bel.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || '] ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_ERROR);
         RETURN v_retorno;
   END;
   
      -- listar las operaciones programadas
   FUNCTION fu_obtenerDetalleProgramada(p_sesion      IN VARCHAR2,
                                        p_codigoCanal IN NUMBER,
                                        p_referencia  IN NUMBER) RETURN typ_opeprogramada IS
      v_retorno       typ_opeprogramada := typ_opeprogramada();
      v_lista         typ_listadetprogramada := typ_listadetprogramada();
      v_detalle       typ_detalleprogramada := typ_detalleprogramada();
      v_msj_respuesta typ_mensajerespuesta := typ_mensajerespuesta();
      v_usu_sesion    paw_bel.typ_validarSesion;
      v_cantidad      NUMBER := 0;
      v_cod_operacion VARCHAR2(3) := '105';
      v_msj_bitacora  VARCHAR2(700);
      v_snp_estado    ge_snp_transferencias.estado%TYPE;
      v_snp_situacion ge_snp_transferencias.situacion%TYPE;
      rg_bopro        bw_ope_programadas%ROWTYPE;
      v_pendientes    NUMBER;
      CURSOR c_detalles IS
         SELECT * 
           FROM bw_ope_programadas_det p
          WHERE p.nro_referencia = p_referencia
          ORDER BY p.nro_detalle;
   BEGIN
      paw_bel.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);    
      
      -- validamos la sesion del user
      v_msj_respuesta := paw_bel.fu_validarActividad(p_sesion, p_codigoCanal);      
      IF v_msj_respuesta.error = 'S' THEN
         v_retorno.error := 'S';
         v_retorno.nombreRespuesta := v_msj_respuesta.nombreRespuesta;
         v_retorno.descripcionRespuesta := v_msj_respuesta.descripcionRespuesta;
         RETURN v_retorno;
      ELSE
         pr_obt_dat_sesion(p_sesion, v_usu_sesion);         
      END IF;
      
      v_msj_bitacora := substr('referencia:' || p_referencia, 1, 700);
                               
      paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_ENTRADA);
      
      BEGIN
         SELECT *
           INTO rg_bopro
           FROM bw_ope_programadas p
          WHERE p.cod_persona = nvl(v_usu_sesion.codigoEmpresa, v_usu_sesion.codigoPersona)
            AND p.nro_referencia = p_referencia;
      EXCEPTION
         WHEN OTHERS THEN
            paw_bel.pr_mensajeUsuario(MSG_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_ERROR);
            RETURN v_retorno;
      END;
      
      v_retorno.numeroReferencia := rg_bopro.nro_referencia;
      v_retorno.frecuencia       := rg_bopro.frecuencia;
      v_retorno.fechaInicio      := rg_bopro.fec_inicio;
      v_retorno.fechaFin         := rg_bopro.fec_fin_plazo;
      v_retorno.fechaSiguiente   := rg_bopro.fec_sig_operacion;
      v_retorno.fechaAnulacion   := rg_bopro.fec_anulacion;
      v_retorno.estado           := rg_bopro.estado;
      v_retorno.concepto         := rg_bopro.concepto;
      v_retorno.monedaOperacion  := rg_bopro.cod_moneda;
      v_retorno.montoOperacion   := rg_bopro.monto;
      v_retorno.cuentaDebito     := rg_bopro.nro_cta_debito;
      v_retorno.cuentaCredito    := rg_bopro.nro_cta_credito;
      v_retorno.nombreCuentaCredito := rg_bopro.nom_cta_credito;
      v_retorno.cantidadProgramada := rg_bopro.can_operaciones;
      v_retorno.cantidadRealizada := rg_bopro.can_ope_realizadas;
      v_retorno.monedaDebito     := rg_bopro.cod_mon_debito;
      v_retorno.monedaCredito    := rg_bopro.cod_mon_credito;
      v_retorno.tipoOperacion    := substr(fue_obt_des_operacion(rg_bopro.cod_tip_mensaje), 1, 100); 
      v_retorno.fechaInsercion   := rg_bopro.fec_insercion;
      
      FOR c IN c_detalles LOOP
         v_detalle.numeroDetalle     := c.nro_detalle;         
         v_detalle.estado            := c.estado;
         -- si es sipap, se debe verificar la situacion de la transferencia
         IF rg_bopro.cod_tip_mensaje = '036' and c.estado = 'C' THEN            
            BEGIN
               SELECT t.estado, t.situacion
                 INTO v_snp_estado, v_snp_situacion
                 FROM ge_snp_transferencias t 
                WHERE t.nro_referencia = c.nro_documento 
                  AND t.fec_valor = c.fecha;
                  
               IF v_snp_estado IN ('C','E','R') OR v_snp_situacion IN ('C','E','T') THEN
                  v_detalle.estado := 'A';
               ELSIF v_snp_situacion = 'L' AND v_snp_estado = 'A' THEN
                  v_detalle.estado := 'C';
               ELSE
                  v_detalle.estado := 'P';
               END IF;                 
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
         END IF;
         v_detalle.fechaProgramada   := c.fec_programada;
         v_detalle.fechaMovimiento   := c.fecha;
         v_detalle.horaMovimiento    := c.hora;
         v_detalle.numeroDocumento   := c.nro_documento;
         v_detalle.montoDebito       := c.mto_debito;
         v_detalle.montoCredito      := c.mto_credito;
         v_detalle.cotizacionDebito  := c.cotizacion;
         v_detalle.cotizacionCredito := c.cot_contra;
         
         v_lista.extend;
         v_lista(v_lista.count) := v_detalle;
         v_cantidad := v_cantidad + 1;
      END LOOP;
      
      -- si el estado es vigente y todavia se inserto la programacion
      -- retornamos la lista de detalle
      IF v_retorno.estado = 'V' THEN
         DECLARE
            rg_bopde bw_ope_programadas_det%ROWTYPE;
         BEGIN
            SELECT COUNT(0)
              INTO v_pendientes
              FROM bw_ope_programadas_det a
             WHERE a.nro_referencia = p_referencia
               AND a.estado = 'P';
            -- se agrega la proxima programacion no insertada a la lista
            IF v_pendientes = 0 THEN
               v_cantidad := v_cantidad + 1;               
               -- cargamos el detalle   
               lp_car_detalles(rg_bopro.nro_referencia, 
                               rg_bopro.cod_tip_mensaje,
                               rg_bopro.fec_sig_operacion,
                               rg_bopro.can_ope_realizadas,
                               rg_bopro.cod_mon_debito,
                               rg_bopro.cod_mon_credito,
                               rg_bopro.monto,
                               rg_bopde);
               -- agregamos a la lista
               v_detalle.numeroDetalle     := rg_bopde.nro_detalle ;
               v_detalle.estado            := rg_bopde.estado;
               v_detalle.fechaProgramada   := rg_bopde.fec_programada;
               v_detalle.fechaMovimiento   := NULL;
               v_detalle.horaMovimiento    := NULL;
               v_detalle.numeroDocumento   := NULL;
               v_detalle.montoDebito       := rg_bopde.mto_debito;
               v_detalle.montoCredito      := rg_bopde.mto_credito;
               v_detalle.cotizacionDebito  := rg_bopde.cotizacion;
               v_detalle.cotizacionCredito := rg_bopde.cot_contra;
         
               v_lista.extend;
               v_lista(v_lista.count) := v_detalle;               
            END IF;
         END;
      END IF;
       
      v_retorno.listaDetalles := v_lista;
      
      paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ', can: ' || v_cantidad || ' ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_SALIDA);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_bel.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_bel.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || '] ' ||paw_bel.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), BITACORA_ERROR);
         RETURN v_retorno;
   END;   
   
   -- procedimiento para notificar las operaciones realizadas
   PROCEDURE pr_not_operaciones IS
      CURSOR c_programados IS
         SELECT *
           FROM bw_ope_programadas_det det
          WHERE det.fec_programada <= pag_cal.fu_obt_fec_actual(9)
            AND det.fec_insercion > trunc(SYSDATE);
      rg_operacion bw_ope_programadas%ROWTYPE;
      v_number NUMBER;
   BEGIN
      
      -- notificamos a los usuarios debitados
      FOR cu IN c_programados LOOP
          BEGIN
             SELECT *
               INTO rg_operacion
               FROM bw_ope_programadas p
              WHERE p.nro_referencia = cu.nro_referencia;
             
             -- sipap tiene su circuito de notificacion, solo se notifica en caso de error
             IF rg_operacion.cod_tip_mensaje <> '036' OR cu.estado = 'A' THEN
                v_number := lf_notificacion(rg_operacion, cu.estado);
             END IF;
          EXCEPTION
             WHEN OTHERS THEN
                NULL;
          END;
      END LOOP;
   END;   
   -- procedimiento para notificar las operaciones realizadas el dia siguiente
   PROCEDURE pr_not_ope_siguiente IS
      CURSOR c_pro_siguiente IS
         SELECT *
           FROM bw_ope_programadas pro
          WHERE trunc(pro.fec_sig_operacion) = pag_cal.fu_obt_fec_proxima(9)
            AND (pro.frecuencia <> 'D' OR (pro.frecuencia = 'D' AND pro.fec_inicio >= pro.fec_sig_operacion));
      v_number NUMBER;
   BEGIN
      
      -- notificamos a los usuarios debitados
      FOR cu IN c_pro_siguiente LOOP
          BEGIN
             v_number := lf_notificacion(cu, 'S');            
          EXCEPTION
             WHEN OTHERS THEN
                NULL;
          END;
      END LOOP;
   END;
   -- actualizar el estado de generacion de comprobante
   PROCEDURE pr_act_est_comprobante(p_nro_referencia IN bw_ope_programadas_det.nro_referencia%TYPE,
                                    p_nro_detalle    IN bw_ope_programadas_det.nro_detalle%TYPE,
                                    p_estado         IN bw_ope_programadas_det.est_comprobante%TYPE) IS
   BEGIN
      UPDATE bw_ope_programadas_det det
         SET det.est_comprobante = p_estado
       WHERE det.nro_referencia = p_nro_referencia
         AND det.nro_detalle = p_nro_detalle
         AND det.est_comprobante = 'P';
   EXCEPTION
     WHEN OTHERS THEN
       lp_reg_error('pr_act_est_comprobante: '||p_nro_referencia ||'-'||p_nro_detalle, SQLERRM);
   END;
   -- invocar al generador de comprobantes web
   PROCEDURE pr_gen_web_comprobante IS
      v_respuesta  TYP_POSTRESPUESTA;
      v_parametros ge_par_dinamicos.val_parametro%TYPE;
      v_url_retry      ge_par_dinamicos.val_parametro%TYPE := 'serv/scheduled_operation/insert_operation_tokens';
      v_url_gateway    ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_SOCK'));
      v_api_gateway    ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_API'));
   BEGIN
      v_parametros := utl_lms.format_message('access_token=%s', v_api_gateway);
      v_respuesta  := fue_env_post(v_parametros, v_url_gateway || v_url_retry);
      IF v_respuesta.error = 'S' OR v_respuesta.codigoError <> 0 THEN
        lp_reg_error('pr_gen_web_comprobante - fue_env_post', v_respuesta.codigoError || ' - ' || v_respuesta.status_code);
      END IF;
   EXCEPTION
     WHEN OTHERS THEN
       lp_reg_error('pr_gen_web_comprobante', SQLERRM);
   END;
   -- inicio mensaje notificacion
   FUNCTION fu_not_inicio RETURN VARCHAR2 IS
   BEGIN
      RETURN '<div style="padding:20px 20px">';
   END;
   -- fin mensaje notificacion
   FUNCTION fu_not_fin RETURN VARCHAR2 IS
   BEGIN
      RETURN '</div>';
   END;
   -- titulo para notificacion
   FUNCTION fu_not_titulo(p_titulo IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      RETURN '<h2 style="color:#074CA9; font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; margin-top:0px">'||p_titulo||'</h2>';
   END;
      -- titulo para notificacion
   FUNCTION fu_not_titulo2(p_titulo IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      RETURN '<h2 style="color:#009DE4; font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; margin-top:0px">'||p_titulo||'</h2>';
   END;
    -- titulo para notificacion con error
   FUNCTION fu_not_titulo_err(p_titulo IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      RETURN '<h2 style="color:#C7175E; font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; margin-top:0px">'||p_titulo||'</h2>';
   END;
   -- subtitulo para notificacion
   FUNCTION fu_not_sub_titulo(p_sub_titulo IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      RETURN '<p style="font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; font-size:14px">'||p_sub_titulo||'</p>';
   END;
   -- subtitulo2 para notificacion
   FUNCTION fu_not_sub_titulo2(p_sub_titulo IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      RETURN '<p style="font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; font-size:11px">'||p_sub_titulo||'</p>';
   END;
   -- inicio tag table
   FUNCTION fu_not_ini_tabla RETURN VARCHAR2 IS
   BEGIN
      RETURN '<table width="500"; style="font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; font-size:14px;">';  
   END;
   -- fin tag table
   FUNCTION fu_not_fin_tabla RETURN VARCHAR2 IS
   BEGIN
      RETURN '</table>';  
   END;
   -- inicio body table
   FUNCTION fu_not_ini_tab_cuerpo RETURN VARCHAR2 IS
   BEGIN
      RETURN '<tbody>';  
   END;
   -- fin body table
   FUNCTION fu_not_fin_tab_cuerpo RETURN VARCHAR2 IS
   BEGIN
      RETURN '</tbody>';  
   END;
   -- fila de informacion para notificacion (detalle)
   FUNCTION fu_not_row_tag(p_tag_izquierda IN VARCHAR2, p_tag_derecha IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      RETURN 
      '<tr>
          <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>'||p_tag_izquierda||':</b></td>
          <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||p_tag_derecha||'</td>
       </tr>';
   END;
--inicializacion del paquete
BEGIN
   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9; --Modulo caja   
END PAW_PRO;
/

