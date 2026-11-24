CREATE OR REPLACE PACKAGE BODY IT.PAW_BEE IS

   DOC_NUMBER_TAG              CONSTANT VARCHAR2(15) := 'docNumber';
   G_NUMBER                    CONSTANT VARCHAR2(15) := 'NUMBER';
   G_VARCHAR                   CONSTANT VARCHAR2(15) := 'VARCHAR';
   G_STRING                    CONSTANT VARCHAR2(15) := 'String';
   PRO_AUT_SIN_PERMISO         CONSTANT VARCHAR2(15) := 'PRO_AUT_SIN_PER';
   PRO_AUT_DOC_INEXISTENTE     CONSTANT VARCHAR2(15) := 'PRO_AUT_DOC_INE';
   PRO_AUT_SAL_INSUFICIENTE    CONSTANT VARCHAR2(15) := 'SAL_CTA_INSUFIC';
   PRO_AUT_CTA_DEB_INV         CONSTANT VARCHAR2(15) := 'SAL_CTA_DEB_INV';
   PRO_AUT_PED_DUPLICADO       CONSTANT VARCHAR2(15) := 'PRO_AUT_DUPLICA';
   PRO_AUT_ERR_INS_DAT_SALARIO CONSTANT VARCHAR2(15) := 'PRO_AUT_DAT_SAL';
   PRO_AUT_ERR_PAG_SALARIO     CONSTANT VARCHAR2(15) := 'PRO_AUT_PAG_SAL';
   PRO_AUT_ERR_SAL_LOTES       CONSTANT VARCHAR2(15) := 'PRO_AUT_SAL_LOT';
   PRO_AUT_ERR_DAT_PROVEEDORES CONSTANT VARCHAR2(15) := 'PRO_ERR_VER_PAG';
   PRO_AUT_ERR_PAG_PROVEEDORES CONSTANT VARCHAR2(15) := 'PRO_ERR_PRO_PAG';
   PRO_AUT_ERR_DNA_MOVIMIENTO  CONSTANT VARCHAR2(15) := 'PRO_AUT_DNA_MOV';
   PRO_AUT_SOL_CHEQUERA        CONSTANT VARCHAR2(15) := 'PRO_AUT_SOL_CHE';
   PRO_AUT_ERR_RECAUDACIONES   CONSTANT VARCHAR2(15) := 'PRO_ERR_REC_PAG';
   PRO_ERR_SIPAP               CONSTANT VARCHAR2(15) := 'PRO_ERR_SIPAP';
   MSG_MOD_CIERRE              CONSTANT VARCHAR2(15) := 'MOD_SIS_CIERRE';
   PRO_AUT_SIN_PERFIL          CONSTANT VARCHAR2(15) := 'PRE_SIN_PERMISO';
   TRA_HOR_OPE_INVAL           CONSTANT VARCHAR2(15) := 'TRA_HOR_OPE_INV';
   TRA_CONTRATO_INVALIDO       CONSTANT VARCHAR2(15) := 'TRA_CON_INVALID';
   PRO_AUT_FEC_INVALIDA        CONSTANT VARCHAR2(15) := 'FECHA_INVA';
   TRI_DNA_ORD_INVALIDA        CONSTANT VARCHAR2(15) := 'TRI_DNA_ORD_INV';
   TRI_DNA_ERR_INTERNO         CONSTANT VARCHAR2(15) := 'TRI_DNA_ERR_INT';
   TRI_DNA_EST_VENCIDO         CONSTANT VARCHAR2(15) := 'TRI_DNA_EST_VEN';
   TRI_DNA_INHABILITADO        CONSTANT VARCHAR2(15) := 'TRI_DNA_INHABIL';
   TRI_BCO_INT_INEXISTE        CONSTANT VARCHAR2(15) := 'TRI_BCO_INT_INE';
   TRI_BCO_BEN_INEXISTE        CONSTANT VARCHAR2(15) := 'TRI_BCO_BEN_INE';
   TRI_BCO_PAI_INEXISTE        CONSTANT VARCHAR2(15) := 'TRI_BCO_PAI_INE';
   TRI_BCO_CIU_INEXISTE        CONSTANT VARCHAR2(15) := 'TRI_BCO_CIU_INE';
   TRI_PAI_COR_INVALIDO        CONSTANT VARCHAR2(15) := 'TRI_PAI_COR_INV';
   TRI_CIU_COR_INVALIDO        CONSTANT VARCHAR2(15) := 'TRI_CIU_COR_INV';
   MSG_OPE_NO_PERMITIDA        CONSTANT VARCHAR2(15) := 'P_OP_NO_PERM';

   -- generico para mensajes de error
   g_msj_error                 VARCHAR2(1000);
   g_cuenta_spi                bw_mov_pendientes.nro_cta_contra%type:=trim(nvl(fug_obt_pardinamico('SPI_CUENTA_HABILITADA'), '3145002708'));

   -- lista de autorizadores participantes de un documento
   CURSOR c_autorizadores(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE) IS
      SELECT p.nom_completo, a.fec_hora, a.observacion, decode('A', 'Autorizado', 'Rechazado') accion
        FROM bw_autorizaciones a, ba_personas p
       WHERE a.nro_documento = p_nro_documento
         AND a.cod_persona = p.cod_persona;

   -- separador de lineas por coma
   CURSOR c_lineas(p_linea IN VARCHAR2, p_separador IN VARCHAR2 DEFAULT ',') IS
     SELECT column_value linea
       FROM
      TABLE (fug_obt_tab_registro(p_linea, p_separador ));

  /** Crea una sesion para el canal y cuenta especificada
  * @param p_password        Contraseña en texto plano
  * @param p_dato            Informacion de tercero que desea iniciar sesion. El tipo esta especificado en p_tipoDato
  * @param p_tipoDato        Codigo del tipo de cuenta que desea iniciar sesion. "D" documento, "K" codigo Persona, "C" tarjeta de credito
  * @param p_nroDocEmpresa   nro de RUC de empresa a la que esta vinculada la persona.Opcional
  * @param p_tipoDocEmpresa  Tipo de Documento de la empresa. "D" RUC
  * @param p_codCanal        Codigo de Canal para el cual se creara la sesion
  * @return retorna informacion de la sesion creada  e informacion referente a la cuenta.
  */
  FUNCTION fu_iniciarsesion(p_password       IN VARCHAR2,
                            p_dato           IN VARCHAR2,
                            p_tipodato       IN VARCHAR2,
                            p_nrodocempresa  IN VARCHAR2,
                            p_tipodocempresa IN VARCHAR2,
                            p_identificadorsesion IN VARCHAR2,
                            p_codcanal       IN VARCHAR2)
    RETURN typ_iniciarsesion IS
    PRAGMA AUTONOMOUS_TRANSACTION;

   BEGIN
      RETURN paw_seg.fu_iniciarsesion(p_password, p_dato, p_tipodato,
                                      p_nrodocempresa, p_tipodocempresa,
                                      p_codcanal);
   END;
   -- obtener datos de movimiento pendiente
   FUNCTION lf_obt_det_pendiente(p_cod_empresa    IN bw_mov_pendientes.cod_per_principal%TYPE,
                                 p_nro_documento  IN bw_mov_pendientes.nro_documento%TYPE,
                                 p_estado         IN bw_mov_pendientes.estado%TYPE,
                                 rg_mov_pendiente OUT NOCOPY bw_mov_pendientes%ROWTYPE) RETURN NUMBER IS
   BEGIN
      SELECT *
        INTO rg_mov_pendiente
        FROM bw_mov_pendientes mp
       WHERE mp.cod_per_principal = p_cod_empresa
         AND mp.nro_documento = p_nro_documento
         AND mp.estado = p_estado;
      RETURN 0;
   EXCEPTION
      WHEN OTHERS THEN
         g_msj_error := substr(SQLERRM, 1, 1000);
         RETURN -1;
   END;
   -- obtener detalle de movimiento pendiente para autorizar/rechazar
   FUNCTION lf_obt_mov_pendiente(p_cod_empresa    IN bw_mov_pendientes.cod_per_principal%TYPE,
                                 p_nro_documento  IN bw_mov_pendientes.nro_documento%TYPE,
                                 rg_mov_pendiente OUT NOCOPY bw_mov_pendientes%ROWTYPE) RETURN NUMBER IS
   BEGIN
      SELECT *
        INTO rg_mov_pendiente
        FROM bw_mov_pendientes mp
       WHERE mp.cod_per_principal = p_cod_empresa
         AND mp.nro_documento = p_nro_documento
         AND
         (
            -- pago salarios, pago proveedores pueden tener fecha futura
            (cod_tip_mensaje not in ('070','075', '008') AND trunc(SYSDATE) = trunc(fec_insercion)) OR
            (cod_tip_mensaje in ('070','075') AND trunc(SYSDATE) <= TRUNC(to_date(dato2,'DD/MM/YYYY'))) OR
            (cod_tip_mensaje = '008' AND TRUNC(SYSDATE - 10) <= TRUNC(fec_insercion))
         );

      RETURN 0;
   EXCEPTION
      WHEN OTHERS THEN
         g_msj_error := substr(SQLERRM, 1, 1000);
         RETURN -1;
   END;
   -- registro de firma autorizacion, convierte a un estado encolado cuando ya no hay firmas faltantes
   PROCEDURE lp_aut_firmar(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE,
                           p_cod_empresa   IN ba_personas.cod_persona%TYPE,
                           p_cod_persona   IN ba_personas.cod_persona%TYPE,
                           p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                           p_comentario    IN VARCHAR2,
                           p_can_faltantes OUT bw_mov_pendientes.can_aut_faltantes%TYPE,
                           p_estado        OUT bw_mov_pendientes.estado%TYPE) IS
   BEGIN
      -- actualizo el movimiento pendiente
      UPDATE bw_mov_pendientes
         SET can_aut_faltantes = nvl(can_aut_faltantes, 0) - 1,
             estado            = decode(can_aut_faltantes, 1, 'E', estado)
       WHERE nro_documento = p_nro_documento
         AND cod_per_principal = p_cod_empresa
      RETURNING can_aut_faltantes, estado INTO p_can_faltantes, p_estado;
      -- inserto el movimiento de autorizacion

      INSERT INTO bw_autorizaciones
         (cod_persona, nro_documento, fec_hora, accion, observacion, cod_canal)
      VALUES
         (p_cod_persona, p_nro_documento, SYSDATE, 'A', p_comentario, p_cod_canal);
   EXCEPTION
      WHEN OTHERS THEN
         p_can_faltantes := -1;
   END;
   --
   PROCEDURE pr_set_pen_enconlado(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE,
                                  p_cod_empresa   IN ba_personas.cod_persona%TYPE,
                                  p_cod_persona   IN ba_personas.cod_persona%TYPE,
                                  p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                                  p_fec_hora      IN bw_mov_pendientes.fec_hora%TYPE) IS
      v_cod_perfil    bw_perfiles.cod_perfil%TYPE;
      v_cod_operacion bw_tip_mensajes.cod_tip_mensaje%TYPE;
      v_permiso typ_permisos;
   BEGIN
      v_cod_perfil := fuw_obt_per_empresa(p_cod_empresa, p_cod_persona);
      v_cod_operacion := fuw_obt_tip_pendiente(p_nro_documento);
      v_permiso := paw_seg.fu_obt_permisos(p_cod_empresa, v_cod_perfil, p_cod_canal, v_cod_operacion);
      IF v_permiso.error = 'S' OR v_permiso.autoriza = 'N' THEN
         raise_application_error(-20000, 'Usuario no cuenta con permiso de autorizacion '||p_cod_persona||'-'||p_cod_empresa);
      END IF;
      -- actualizo el movimiento pendiente para que se pueda volver a firmar
      UPDATE bw_mov_pendientes
         SET can_aut_faltantes = 1,
             estado            = 'P'
       WHERE nro_documento = p_nro_documento
         AND cod_per_principal = p_cod_empresa
         AND TRUNC(fec_hora) = TRUNC(p_fec_HORA);
      -- inserto el movimiento de autorizacion

      DELETE
        FROM bw_autorizaciones a
       WHERE a.cod_persona = p_cod_persona
         AND a.nro_documento = p_nro_documento
         AND trunc(a.fec_hora) = TRUNC(p_fec_hora);
   END;
   -- ----- utilitarios para proveedores --
   PROCEDURE lp_cam_fec_pag_proveedores(p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                        p_fec_pago      IN OUT ge_pag_proveedores.fec_pago%TYPE,
                                        p_nro_archivo   IN OUT ge_pag_proveedores.nro_archivo%TYPE) IS
      v_nro_arc_original ge_pag_proveedores_tmp.nro_archivo%TYPE := p_nro_archivo;
      v_fec_pag_original ge_pag_proveedores_tmp.fec_pago%TYPE := p_fec_pago;
      v_nro_sec_sgte     ge_pag_proveedores_tmp.nro_archivo%TYPE;
   BEGIN
      p_fec_pago := pag_cal.FU_OBT_FEC_HABIL(p_fec_pago + 1,1,1);
      
      -- obtenemos la siguiente secuencia de pago para cambio de fecha
      SELECT s_bw_nro_arc_proveedor.nextval
        INTO v_nro_sec_sgte 
        FROM dual;

      v_nro_sec_sgte := v_nro_sec_sgte + p_nro_archivo + pag_prv.fu_obt_nro_secuencia(p_mov_pendiente.dato, p_fec_pago);

      -- se cambia la fecha de pago al dia habil siguiente
      UPDATE ge_pag_proveedores_tmp gp
         SET gp.fec_pago = p_fec_pago,
             gp.nro_archivo = v_nro_sec_sgte
       WHERE gp.cod_ente = p_mov_pendiente.dato
         AND gp.estado = 'C'
         AND gp.tip_carga = 'H'
         AND gp.fec_pago = v_fec_pag_original
         AND gp.nro_archivo = v_nro_arc_original
         AND trunc(gp.fec_insercion) = trunc(p_mov_pendiente.fec_insercion);
      -- actualizamos los datos de referencia del pendiente
      UPDATE bw_mov_pendientes
            SET referencia = v_nro_sec_sgte, dato2 = to_char(p_fec_pago, 'DD/MM/YYYY')
          WHERE nro_documento = p_mov_pendiente.nro_documento
            AND cod_per_principal = p_mov_pendiente.cod_per_principal;
            
      p_nro_archivo := v_nro_sec_sgte;
   END lp_cam_fec_pag_proveedores;
   
   PROCEDURE lp_act_fec_pag_proveedores(p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                        p_fec_pago      IN OUT ge_pag_proveedores.fec_pago%TYPE,
                                        p_nro_archivo   IN OUT ge_pag_proveedores.nro_archivo%TYPE) IS
      v_cam_fecha BOOLEAN;
      v_cantidad  NUMBER;
      v_hora_fin  ge_snp_horarios.hor_fin%TYPE;
      v_hora_pro  ge_snp_horarios.hor_fin%TYPE;
      v_fec_pago  ge_pag_proveedores.fec_pago%TYPE := p_fec_pago;
   BEGIN
      IF p_fec_pago = TRUNC(SYSDATE) THEN
         -- el sgte. proc cambia la fecha, por eso se copia en un var. aux.
         -- porque se puede cambiar de vuelta en lp_cam_fec_pag_proveedores
         v_cam_fecha := paw_bce.fu_ver_hor_cie_proveedor(v_fec_pago);
         -- verificar si el horario sipap esta cerrado y tiene pagos sipap, cambiar la fecha
         IF v_cam_fecha = FALSE THEN
            v_cantidad := paw_can.fu_obt_pag_snp_proveedores(p_mov_pendiente.dato, p_fec_pago, p_nro_archivo);
            v_hora_fin := paw_bas.fu_obt_hor_fin_snp(1);
            v_hora_pro := TO_CHAR(SYSDATE,'HH24MI');
            IF TO_NUMBER(v_hora_pro) >= TO_NUMBER(v_hora_fin) AND v_cantidad > 0 THEN
               -- sipap cerrado, se debe cambiar la fecha de pago
               v_cam_fecha := TRUE;
            END IF;
         END IF;
         IF v_cam_fecha THEN
            -- puede cambiar la fecha de pago y el numero de archivo
            lp_cam_fec_pag_proveedores(p_mov_pendiente, p_fec_pago, p_nro_archivo);
         END IF;
      END IF;
   END lp_act_fec_pag_proveedores;
   -- -------------------------------------
   -- validaciones de movimiento pendiente
   FUNCTION fu_val_doc_autorizacion(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE,
                                    p_cod_empresa   IN OUT ba_personas.cod_persona%TYPE,
                                    p_cod_persona   IN ba_personas.cod_persona%TYPE,
                                    p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                                    p_estado        IN VARCHAR2,
                                    p_detalle       IN OUT typ_detallependiente) RETURN typ_mensajerespuesta IS
      v_retorno           typ_mensajerespuesta := typ_mensajerespuesta();
      v_permiso           typ_permisos := typ_permisos();
      v_cod_msj_operacion bw_tip_mensajes.cod_tip_mensaje%TYPE;
      v_cod_perfil        bw_rol_permisos.cod_perfil%TYPE;
      rg_bmpen            bw_mov_pendientes%ROWTYPE;
      v_cod_tra_padre     ge_transacciones.cod_transaccion%TYPE;
      v_tip_pro_sueldo    VARCHAR2(1);
      v_cod_respuesta     NUMBER;

      -- datos basicos de cuenta
      PROCEDURE lp_obt_dat_cuenta(p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                                  p_tip_cuenta    OUT VARCHAR2) IS
      BEGIN
         SELECT substr(fug_obt_des_modal(c.cod_modulo, c.cod_modalidad), 1, 50)
           INTO p_tip_cuenta
           FROM ge_cuentas c
          WHERE c.nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            p_tip_cuenta := NULL;
      END;
   BEGIN
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      -- DDSI-238 -- 01/2018 -- Verificar estado del modulo
      IF pae_cnf.FU_OBT_EST_MODULO(3) IN (1,6) THEN
         paw_uti.pr_mensajeUsuario(MSG_MOD_CIERRE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;

      IF nvl(paw_bas.fu_val_gen_ope_cierre, 'S') = 'N' THEN
         paw_uti.pr_mensajeUsuario(MSG_MOD_CIERRE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;

      -- 2. verifico la accion
      IF p_cod_empresa IS NULL THEN
         BEGIN
            SELECT MIN(cod_per_principal)
              INTO p_cod_empresa -- esta es una solucion para que los clientes fisicos de cuentas conjuntas puedan autorizarse
              FROM bw_mov_pendientes a
             WHERE estado = 'P'
               AND pag_gen.FU_ES_PER_FISICA(cod_per_principal) = 'S'
               AND cod_per_principal <> p_cod_persona
               AND EXISTS (SELECT 0
                             FROM ge_cta_clientes b
                            WHERE b.nro_cuenta = a.nro_cuenta
                              AND b.cod_persona = p_cod_persona);
         EXCEPTION
            WHEN OTHERS THEN
               paw_uti.pr_mensajeusuario(PRO_AUT_SIN_PERMISO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;
         END;
      END IF;
      -- 1. busco los datos de la operacion pendiente
      IF lf_obt_mov_pendiente(p_cod_empresa, p_nro_documento, rg_bmpen) < 0 THEN
         paw_uti.pr_mensajeusuario(PRO_AUT_SIN_PERMISO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      -- verificar si tiene permiso para autorizar esa operacion
      v_cod_msj_operacion := rg_bmpen.cod_tip_mensaje;
      IF v_cod_msj_operacion = '071' THEN
         --acreditacion gourmet usa los mismos permisos que pago de salarios
         v_cod_msj_operacion := '070';
      END IF;
      -- verificamos si el perfil cuenta con permiso para autorizar operaciones(023)
      v_cod_perfil := fuw_obt_per_empresa(p_cod_empresa, p_cod_persona);
      v_permiso := paw_seg.fu_obt_permisos(p_cod_empresa, v_cod_perfil, p_cod_canal, '023');
      IF v_permiso.error = 'N' AND v_permiso.autoriza = 'S' THEN
         -- se verificar si tiene permiso para autorizar la operacion en si (030, 070, etc.)
         v_permiso := paw_seg.fu_obt_permisos(p_cod_empresa, v_cod_perfil, p_cod_canal, v_cod_msj_operacion);
      END IF;
      IF v_permiso.error = 'S' THEN
         v_retorno.nombreRespuesta      := v_permiso.nombreRespuesta;
         v_retorno.descripcionRespuesta := v_permiso.descripcionRespuesta;
         v_retorno.error                := v_permiso.error;
         RETURN v_retorno;
      END IF;
      IF v_permiso.autoriza = 'N' THEN
         paw_uti.pr_mensajeUsuario(PRO_AUT_SIN_PERMISO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      -- para validacion de estado, no se puede firmar un estado pendiente.
      -- tampoco se puede autorizar un estado que no sea encolado.
      IF rg_bmpen.estado <> nvl(p_estado, 'P') THEN
         paw_uti.pr_mensajeusuario(PRO_AUT_PED_DUPLICADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      --
      p_detalle.numeroDocumento          := rg_bmpen.nro_documento;
      p_detalle.fechaHora                := rg_bmpen.fec_hora;
      p_detalle.numeroCuenta             := rg_bmpen.nro_cuenta;
      p_detalle.codigoMoneda             := rg_bmpen.cod_moneda;
      p_detalle.monto                    := rg_bmpen.monto;
      p_detalle.codTipOperacion          := rg_bmpen.cod_tip_mensaje;
      p_detalle.cantidad                 := rg_bmpen.cantidad;
      p_detalle.perRegistro              := substr(fue_obt_nom_persona(rg_bmpen.cod_per_ingreso), 1, 100);
      p_detalle.autorizacionesRequeridas := rg_bmpen.can_aut_requeridas;
      p_detalle.autorizacionesFaltantes  := rg_bmpen.can_aut_faltantes;
      p_detalle.tipPago                  := rg_bmpen.tip_pago;
      p_detalle.estado                   := rg_bmpen.estado;
      p_detalle.perRegistro              := substr(fue_obt_nom_persona(rg_bmpen.cod_per_ingreso), 1, 200);
      p_detalle.etiqueta                 := rg_bmpen.etiqueta;
      p_detalle.dato                     := rg_bmpen.dato;
      p_detalle.etiqueta2                := rg_bmpen.etiqueta2;
      p_detalle.dato2                    := rg_bmpen.dato2;
      -- datos de la cuenta
      lp_obt_dat_cuenta(rg_bmpen.nro_cuenta, p_detalle.tipoCuenta);
      -- validaciones
      IF rg_bmpen.cod_tip_mensaje in ('070', '071') THEN
         IF rg_bmpen.cod_tip_mensaje = '071' THEN
            --Si el servicio es Gourmet, se trae la cuenta padre
            v_cod_tra_padre := NVL(FUG_OBT_PARDINAMICO('GOU_CTA_PADRE'), 5166);
         ELSE
            -- obtenemos la transaccion padre
            v_cod_tra_padre := paw_bel.fu_obt_tra_sueldo(rg_bmpen.dato, rg_bmpen.tip_pago);
            -- obtenemos el tipo de proceso de sueldo para el ente
            v_tip_pro_sueldo  := paw_bel.fu_obt_tip_pro_sueldo(rg_bmpen.dato);

            IF TRUNC(TO_DATE(rg_bmpen.dato2, 'DD/MM/YYYY')) > TRUNC(rg_bmpen.fec_insercion) THEN
               v_tip_pro_sueldo := 'B';
            END IF;
            -- pagos de aguinalo seran Online y Cancelar con errores independientemente de
            -- la configuracion del ente
            IF rg_bmpen.tip_pago = 'A' THEN
               v_tip_pro_sueldo  := 'O';
            END IF;
         END IF;

         -- verificamos si se puede realizar la operacion de debito
         IF paw_bce.fu_ver_operacion(rg_bmpen.nro_cuenta, rg_bmpen.monto, 503, v_cod_tra_padre, 'D') = 'N' THEN
            IF pag_cta.g_cod_error <> 0 THEN
               --Verificacion de la operacion retorna error. Se verifica si corresponde a insuficiencia de fondos
               IF pag_cta.g_cod_error IN (25, 29, 31, 36) THEN
                  IF rg_bmpen.cod_tip_mensaje = '070' THEN
                     -- En el caso de Pago de salarios se verifica saldo solo si es pago online
                     IF v_tip_pro_sueldo = 'O' OR (v_tip_pro_sueldo = 'B' AND TRUNC(SYSDATE) = TRUNC(TO_DATE(rg_bmpen.dato2, 'DD/MM/YYYY'))) THEN
                        paw_uti.pr_mensajeusuario(PRO_AUT_SAL_INSUFICIENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     END IF;
                  ELSE
                     -- La cuenta no tiene saldo suficiente
                     paw_uti.pr_mensajeusuario(PRO_AUT_SAL_INSUFICIENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  END IF;
               ELSE
                  -- Ocurrio un error distinto a insuficiencia de fondos
                  paw_uti.pr_mensajeusuario(PRO_AUT_CTA_DEB_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  g_msj_error := substr(pag_cta.G_MSJ_ERROR, 1, 1000);
               END IF;
               RETURN v_retorno;
            END IF;
         END IF;
      END IF;
      -- validar el horarios
      DECLARE
         v_nro_pre_pactado   NUMBER;
         v_nro_archivo       bw_mov_pendientes.referencia%TYPE;
         rv_lctran           lc_transferencias%ROWTYPE;
         v_cod_mon_credito   ba_monedas.cod_moneda%TYPE;
         v_cod_msj_swift     ge_snp_transferencias.cod_msj_swift%TYPE;
         v_tip_operacion     ge_snp_transferencias.cod_tip_operacion%TYPE;
         v_sub_tip_operacion ge_snp_transferencias.cod_sub_tip_operacion%TYPE;
         v_est_snp_periodo   ge_snp_horarios.estado%TYPE;
         v_fec_pago          DATE;
         v_error             VARCHAR2(5000);
         v_val_dna           VARCHAR2(1) := 'N';
      BEGIN
         CASE rg_bmpen.cod_tip_mensaje
            WHEN '036' THEN -- sipap   
              if  rg_bmpen.nro_cta_contra<>g_cuenta_spi  then
                   SELECT t.cod_msj_swift, t.cod_tip_operacion, t.cod_sub_tip_operacion
                     INTO v_cod_msj_swift, v_tip_operacion, v_sub_tip_operacion
                     FROM ge_snp_transferencias t
                    WHERE t.nro_referencia = rg_bmpen.referencia;
                   
                    v_est_snp_periodo := pas_snp.fu_obt_est_horario(v_cod_msj_swift, v_tip_operacion, v_sub_tip_operacion);
               end if;     

               v_cod_mon_credito := TRIM(REGEXP_REPLACE(rg_bmpen.dato,'([[:print:]]+)\*([[:print:]]+)\*([[:print:]]+)','\2'));
               v_nro_pre_pactado := REGEXP_REPLACE(rg_bmpen.dato,'([[:print:]]+)\*([[:print:]]+)\*([[:print:]]+)','\3');
            WHEN '075' THEN -- pago proveedores
               v_est_snp_periodo := pas_snp.fu_obt_est_horario('103', '001', '002');
               v_fec_pago        := TRUNC(to_date(rg_bmpen.dato2, 'DD/MM/YYYY'));
               v_nro_archivo     := rg_bmpen.referencia;
               v_nro_pre_pactado := NULL;
               
               -- verifico la hora de cierre y actualizo fec_pago y/o nro_archivo si corresponde.
               lp_act_fec_pag_proveedores(rg_bmpen, v_fec_pago, v_nro_archivo);
      
               -- verificar datos temporales
               pag_prv.pr_ver_dat_tmp(rg_bmpen.dato, v_fec_pago, NULL, v_error, 'N', rg_bmpen.nro_documento, rg_bmpen.nro_cuenta, v_nro_archivo, rg_bmpen.fec_insercion);
               
               IF v_error IS NOT NULL THEN
                  IF instr(v_error, 'Horario SIPAP Cerrado') > 0 THEN
                     paw_uti.pr_mensajeUsuario(PRO_ERR_SIPAP, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  ELSE
                     paw_uti.pr_mensajeusuario(PRO_AUT_ERR_DAT_PROVEEDORES, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  END IF;
                  g_msj_error := g_msj_error || ', PRV-ERR:[' || SUBSTR(v_error, 1, 150)||']';
                  RETURN v_retorno;
               END IF;
            WHEN '039' THEN -- transf. teceros
               v_nro_pre_pactado := rg_bmpen.referencia;
            WHEN '060' THEN -- solicitud de chequeras
               IF nvl(fug_obt_es_per_inhi(p_cod_persona), 'X') = 'S'  THEN
                  paw_uti.pr_mensajeUsuario(MSG_OPE_NO_PERMITIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  g_msj_error := g_msj_error || ' - persona inhibida';
                  RETURN v_retorno;
               END IF;
            WHEN '227' THEN -- transferencia internacional
               pr_obt_dat_tra_internacional(rg_bmpen.nro_documento, rg_bmpen.fec_hora, rg_bmpen.cod_per_principal,
                                          -- variables salida
                                          rv_lctran.nom_beneficiario, rv_lctran.dir_beneficiario, rv_lctran.nro_cta_referencia,
                                          rv_lctran.nom_banco, rv_lctran.cod_pai_banco, rv_lctran.cod_ciu_banco,
                                          rv_lctran.cod_bco_corresponsal, rv_lctran.nom_bco_cor_contra, rv_lctran.cod_swi_bco_contra,
                                          rv_lctran.cod_pai_bco_contra, rv_lctran.cod_ciu_bco_contra, rv_lctran.cod_moneda,
                                          v_nro_pre_pactado, -- contrato de cambio 
                                          rv_lctran.tip_cargo, rv_lctran.plazo, rv_lctran.tip_motivo, rv_lctran.tip_fondo,
                                          rv_lctran.tip_financiacion, rv_lctran.cod_swi_banco, rv_lctran.referencia,
                                          rv_lctran.cod_pai_beneficiario, rv_lctran.cod_ciu_beneficiario, rv_lctran.nro_ord_pag_dna);
               
               
               v_cod_respuesta := pal_tra.fu_val_banco(rg_bmpen.dato2, rv_lctran.cod_pai_banco, rv_lctran.cod_ciu_banco);  
               IF v_cod_respuesta = 0 THEN
                  v_cod_respuesta := pal_tra.fu_val_bco_corresponsal(rv_lctran.cod_bco_corresponsal, rv_lctran.cod_pai_bco_contra, rv_lctran.cod_ciu_bco_contra);  
               END IF;
               
               CASE v_cod_respuesta
                  WHEN  0 THEN -- OK
                     NULL;
                  WHEN -8 THEN -- Banco Intermediario Inexistente
                     paw_uti.pr_mensajeUsuario(TRI_BCO_INT_INEXISTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  WHEN -9 THEN -- Banco del Beneficiario Inexistente
                     paw_uti.pr_mensajeUsuario(TRI_BCO_BEN_INEXISTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  WHEN -10 THEN -- Pais de Banco del Beneficiario no corresponde
                     paw_uti.pr_mensajeUsuario(TRI_BCO_PAI_INEXISTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  WHEN -11 THEN -- Ciudad de Banco del Beneficiario no corresponde
                     paw_uti.pr_mensajeUsuario(TRI_BCO_CIU_INEXISTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  WHEN -12 THEN -- Pais de Banco del Intermediario no corresponde
                     paw_uti.pr_mensajeUsuario(TRI_PAI_COR_INVALIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  WHEN -13 THEN -- Ciudad de Banco del Intermediario no corresponde
                     paw_uti.pr_mensajeUsuario(TRI_CIU_COR_INVALIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  ELSE
                     paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               END CASE;
               IF v_retorno.error = 'S' THEN
                  RETURN v_retorno;
               END IF;
               
               -- Validar ticket DNA si corresponde
               BEGIN 
                  SELECT 'S' 
                    INTO v_val_dna
                    FROM ba_cod_referencias r
                   WHERE r.dominio = 'TRA_TIP_MOT_DNA'
                     AND r.val_minimo = rv_lctran.tip_motivo;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     v_val_dna := 'N';
               END;
            WHEN '214' THEN -- transf. con contrato
               v_nro_pre_pactado := 10; -- no importa el valor, se debe valir el horario
            ELSE
               v_nro_pre_pactado := NULL;
         END CASE;
         -- si hay contrato prepactado, verificar el horario
         IF nvl(v_nro_pre_pactado, 0) <> 0 AND paw_bas.fu_ver_hor_contrato() = 'N' THEN
            paw_uti.pr_mensajeusuario(TRA_HOR_OPE_INVAL, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);      
            RETURN v_retorno;
         END IF;
         -- verificar si hay cambio de moneda y sipap cerrado
         IF rg_bmpen.cod_tip_mensaje = '036' THEN
            IF v_est_snp_periodo <> 'A' AND v_cod_mon_credito <> rg_bmpen.cod_moneda and rg_bmpen.nro_cta_contra<>g_cuenta_spi THEN
               paw_uti.pr_mensajeUsuario(PRO_AUT_FEC_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;
            END IF;
         END IF;

         -- verificar si hay operaciones de cambio sipap, en tal caso no puede estar cerrado el horario
         IF rg_bmpen.cod_tip_mensaje = '075' AND v_fec_pago = trunc(sysdate) THEN
            IF v_est_snp_periodo <> 'A' AND pag_prv.fu_obt_can_ope_cambio(rg_bmpen.dato, v_fec_pago, rg_bmpen.cod_moneda, rg_bmpen.referencia, 'S') > 0 THEN
               paw_uti.pr_mensajeUsuario(PRO_AUT_FEC_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;
            END IF;
         END IF;
         -- verificar si se debe valir orden de pago DNA
         IF rg_bmpen.cod_tip_mensaje = '227' AND v_val_dna = 'S' THEN
            DECLARE
               v_dna_fec_creacion DATE;
               v_dna_fec_vencimiento DATE;
               v_dna_cod_mon_origen VARCHAR2(50);
               v_dna_sal_origen  NUMBER;
               v_dna_cotizacion  NUMBER;
               v_nro_doc_persona ba_personas.nro_documento%TYPE;
               v_tip_doc_persona ba_personas.cod_tip_documento%TYPE;
               v_cod_respuesta   NUMBER;
            BEGIN
               SELECT p.nro_documento, p.cod_tip_documento
                 INTO v_nro_doc_persona, v_tip_doc_persona
                 FROM ba_personas p
                WHERE p.cod_persona = rg_bmpen.cod_per_principal;
               pal_tra.pr_con_bol_pag_dna(rv_lctran.nro_ord_pag_dna,
                                          rv_lctran.cod_moneda,
                                          rg_bmpen.mto_contra, -- v_mto_credito,
                                          v_nro_doc_persona,
                                          v_tip_doc_persona,
                                          --respuesta DNA
                                          v_dna_cod_mon_origen, 
                                          v_dna_fec_creacion,
                                          v_dna_fec_vencimiento,
                                          v_dna_sal_origen,
                                          v_dna_cotizacion,
                                          v_cod_respuesta, -- 0 sino hubo errores
                                          g_msj_error);
               CASE v_cod_respuesta
                  WHEN 0 THEN 
                     NULL; -- OK
                  WHEN 3 THEN
                     paw_uti.pr_mensajeUsuario(TRI_DNA_ERR_INTERNO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  WHEN 11 THEN
                     paw_uti.pr_mensajeUsuario(TRI_DNA_EST_VENCIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  WHEN 12 THEN
                     paw_uti.pr_mensajeUsuario(TRI_DNA_INHABILITADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  ELSE
                     paw_uti.pr_mensajeUsuario(TRI_DNA_ORD_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               END CASE;  
            END;   
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            g_msj_error := substr(SQLERRM, 1, 1000);
            paw_uti.pr_mensajeusuario(TRA_CONTRATO_INVALIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
      END;
      RETURN v_retorno;
   END;
   -- obtener autorizadores de un mov. pendiente
   FUNCTION fu_obt_autorizadores(p_nro_documento IN bw_autorizaciones.nro_documento%TYPE) RETURN typ_listadetalleautorizador IS
      v_retorno     typ_listadetalleautorizador := typ_listadetalleautorizador();
      v_autorizador typ_detalleAutorizador := typ_detalleAutorizador();
   BEGIN
      -- cargamos los autorizadores participantes si existen
      FOR reg IN c_autorizadores(p_nro_documento) LOOP
         v_autorizador.nombre     := substr(reg.nom_completo, 1, 100);
         v_autorizador.fechaHora  := reg.fec_hora;
         v_autorizador.comentario := substr(reg.observacion, 1, 250);
         v_autorizador.estado     := substr(reg.accion, 1, 20);
         v_retorno.extend;
         v_retorno(v_retorno.count) := v_autorizador;
      END LOOP;
      RETURN v_retorno;
   END;
   -- disminuye la cantidad de firmas faltantes si esta ok el mov. pendiente
   FUNCTION fu_firmarOperacion(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                               p_cod_empresa     IN ba_personas.cod_persona%TYPE,
                               p_cod_canal       IN cj_cajas.nro_caja%TYPE,
                               p_nro_documento   IN VARCHAR2) RETURN typ_firmaOperacion IS

      -- datos recibidos
      v_retorno           typ_firmaOperacion := typ_firmaOperacion();
      v_det_autorizacion  typ_mensajerespuesta;
      v_det_pendiente     typ_detallependiente := typ_detallependiente();
      v_cod_per_empresa   ba_personas.cod_persona%TYPE := substr(p_cod_empresa, 1, 10);
      v_can_aut_faltantes bw_mov_pendientes.can_aut_faltantes%TYPE := -2;
      v_estado            bw_mov_pendientes.estado%TYPE;
         
   BEGIN
      v_det_autorizacion := fu_val_doc_autorizacion(p_nro_documento, v_cod_per_empresa, p_cod_persona, p_cod_canal, 'P', v_det_pendiente);
      -- se firma si no tiene errores
      IF v_det_autorizacion.error = 'N' THEN
         lp_aut_firmar(p_nro_documento, v_cod_per_empresa, p_cod_persona, p_cod_canal, null, v_can_aut_faltantes, v_estado);
         IF v_can_aut_faltantes < 0 THEN
            paw_uti.pr_mensajeUsuario(PRO_AUT_PED_DUPLICADO, v_det_autorizacion.nombreRespuesta, v_det_autorizacion.descripcionRespuesta, v_det_autorizacion.error);
         ELSE
            -- se actualiza para agregar la cola de proceso
            v_det_pendiente.estado := v_estado;
            v_det_pendiente.datosCantidad := 0;
            v_det_pendiente.datosAdicionales := NULL;
            v_det_pendiente.autorizacionesFaltantes := v_can_aut_faltantes;
         END IF;
      ELSE
         BEGIN
            select p.cod_tip_mensaje, p.cod_moneda, p.estado, p.can_aut_faltantes, p.nro_documento
              into v_det_pendiente.codTipOperacion, v_det_pendiente.codigoMoneda, v_det_pendiente.estado, v_det_pendiente.autorizacionesFaltantes, v_det_pendiente.numeroDocumento
              from bw_mov_pendientes p
             where p.nro_documento = p_nro_documento
               and p.cod_per_principal = p_cod_empresa;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END IF;
      IF v_det_autorizacion.error = 'S' THEN
         paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, 'xxxxxxxxx', v_det_pendiente.codTipOperacion, p_cod_empresa, 'err: ['||nvl(g_msj_error, 'xx')||'] '|| paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
      END IF;
      v_retorno.error := v_det_autorizacion.error;
      v_retorno.nombreRespuesta := v_det_autorizacion.nombreRespuesta;
      v_retorno.descripcionRespuesta := v_det_autorizacion.descripcionRespuesta;
      v_retorno.detalle := v_det_pendiente;
      RETURN v_retorno;
   END;
   --
   PROCEDURE lp_aut_tra_propia(p_sesion        IN VARCHAR2,
                               p_cod_canal     IN VARCHAR2,
                               p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                               p_retorno       IN OUT typ_mapa) IS
      v_transferencia typ_transferenciaban;
   BEGIN
      v_transferencia := paw_bel.fu_transferenciasPropias(p_sesion, p_cod_canal,
                                                          p_mov_pendiente.nro_cuenta, -- cuenta debito
                                                          p_mov_pendiente.monto,      -- monto operacion
                                                          p_mov_pendiente.nro_cta_contra, -- cuentra credito
                                                          'A',           -- autorizar
                                                          p_mov_pendiente.dato2,  -- concepto
                                                          p_mov_pendiente.cotizacion, -- cotizacion debito
                                                          p_mov_pendiente.cot_contra, -- cotizacion credito
                                                          p_mov_pendiente.mto_contra, -- monto credito
                                                          NULL, NULL);
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_transferencia.nroDocumento, G_NUMBER);
      p_retorno.error                := v_transferencia.error;
      p_retorno.nombreRespuesta      := v_transferencia.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_transferencia.descripcionRespuesta;
   END;
   --
   PROCEDURE lp_aut_pag_prestamo(p_sesion        IN VARCHAR2,
                                 p_cod_canal     IN VARCHAR2,
                                 p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                 p_retorno       IN OUT typ_mapa) IS
      v_prestamo typ_pagoprestamo;
   BEGIN
      v_prestamo := paw_bel.fu_pagoPrestamo(p_sesion, p_cod_canal,
                                            p_mov_pendiente.nro_cta_contra, -- numero prestamo
                                            p_mov_pendiente.nro_cuenta,     -- cuenta debito
                                            p_mov_pendiente.dato,           -- cantidad de cuotas
                                            p_mov_pendiente.monto,          -- monto del prestamo
                                            'A', NULL, NULL);
      p_retorno.error                := v_prestamo.error;
      p_retorno.nombreRespuesta      := v_prestamo.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_prestamo.descripcionRespuesta;
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_prestamo.nroDocumento, G_NUMBER);
   END;
   --
   PROCEDURE lp_aut_pag_tarjeta(p_sesion        IN VARCHAR2,
                                p_cod_canal     IN VARCHAR2,
                                p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                p_retorno       IN OUT typ_mapa) IS
      v_pagotarjeta typ_pagoTarjetaCredito;
   BEGIN
      -- para que inserte en gw_par_web_servicios,
      pat_val.g_proceso := 'PAW_BEE_LP_AUT_PAG_TARJETA';
      v_pagotarjeta := paw_bel.fu_pagoTarjetaCredito(p_sesion,
                                             p_cod_canal,
                                             p_mov_pendiente.dato, -- numero tarjeta
                                             p_mov_pendiente.nro_cuenta, -- cuenta debito
                                             'A', -- autorizar
                                             NULL, -- numero sobre
                                             0, -- importe efectivo
                                             0, -- cheque nuestro banco
                                             0, -- cheque otro banco
                                             p_mov_pendiente.monto, -- importe debito
                                             p_mov_pendiente.monto, -- total pago
                                             NULL, NULL,
                                             'S'); -- online, se enviara por el gwscheduler
      p_retorno.error                := v_pagotarjeta.error;
      p_retorno.nombreRespuesta      := v_pagotarjeta.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_pagotarjeta.descripcionRespuesta;
      pat_val.g_proceso := null;
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_pagotarjeta.numeroOperacion, G_NUMBER);
   END;
   --
   PROCEDURE lp_aut_pag_aduana(p_sesion        IN VARCHAR2,
                               p_cod_canal     IN VARCHAR2,
                               p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                               p_retorno       IN OUT typ_mapa) IS
      v_msj_original bw_movimientos.observacion%TYPE;
      v_aduana       typ_pagoAduana;
   BEGIN
      SELECT observacion
        INTO v_msj_original
        FROM bw_movimientos
       WHERE nro_documento = p_mov_pendiente.nro_documento
         AND trunc(fec_hora) = trunc(p_mov_pendiente.fec_hora)
         AND cod_per_principal = p_mov_pendiente.cod_per_principal
         AND cod_tip_mensaje = '033';

      v_aduana := paw_bel.fu_pagoAduana(p_sesion,
                                        p_cod_canal,
                                        p_mov_pendiente.nro_cuenta,  -- cuenta debito
                                        'A',            -- autorizacion
                                        p_mov_pendiente.monto,       -- monto
                                        trim(substr(v_msj_original, 1, 3)),   -- TID, TCA, TLE, TDA
                                        trim(substr(v_msj_original, 4, 18)),  -- campo1
                                        trim(substr(v_msj_original, 22, 18)), -- campo2
                                        trim(substr(v_msj_original, 40, 50)),  -- nombre importador
                                        trim(substr(v_msj_original, 90, 50)), -- nombre despachante
                                        NULL, NULL);
      p_retorno.error                := v_aduana.error;
      p_retorno.nombreRespuesta      := v_aduana.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_aduana.descripcionRespuesta;
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_aduana.nroDocumento, G_NUMBER);
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeusuario(PRO_AUT_ERR_DNA_MOVIMIENTO, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         g_msj_error := SUBSTR(SQLERRM, 1, 1000);
   END;
   --
   PROCEDURE lp_aut_tra_snp(p_sesion        IN VARCHAR2,
                            p_cod_canal     IN VARCHAR2,
                            p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                            p_retorno       IN OUT typ_mapa) IS
      v_tra_interbancaria typ_transferenciainterbancaria;
      v_cod_mon_credito   ba_monedas.cod_moneda%TYPE;
      v_nro_pre_pactado   lc_ope_pendientes.nro_diario%TYPE;
      v_fec_operacion     ge_snp_transferencias.fec_valor%TYPE;
      v_hora_fin          ge_snp_horarios.hor_fin%TYPE;
      v_hora_pro          ge_snp_horarios.hor_fin%TYPE;
      v_cod_periodo       ge_snp_horarios.cod_periodo%TYPE;
     
   BEGIN
      v_cod_mon_credito   := REGEXP_REPLACE(p_mov_pendiente.dato,'([[:print:]]+)\*([[:print:]]+)\*([[:print:]]+)','\2');
      v_nro_pre_pactado   := REGEXP_REPLACE(p_mov_pendiente.dato,'([[:print:]]+)\*([[:print:]]+)\*([[:print:]]+)','\3');
      v_fec_operacion     := to_date(p_mov_pendiente.dato2, 'DD/MM/YYYY');
        
 if p_mov_pendiente.nro_cta_contra<>g_cuenta_spi then
      IF TRUNC(v_fec_operacion) = TRUNC(SYSDATE) THEN
         SELECT h.cod_periodo
           INTO v_cod_periodo
           FROM ge_snp_transferencias t, ge_snp_par_mensajes h
           WHERE t.nro_referencia = p_mov_pendiente.referencia
             AND t.cod_msj_swift = h.cod_msj_swift
             AND t.cod_tip_operacion = h.cod_tip_operacion
             AND t.cod_sub_tip_operacion = h.cod_sub_tip_operacion
             AND t.cod_tra_padre = h.cod_tra_padre;

         v_hora_fin := paw_bas.fu_obt_hor_fin_snp(v_cod_periodo);
         v_hora_pro := TO_CHAR(SYSDATE, 'HH24MI');
         IF TO_NUMBER(v_hora_pro) >= TO_NUMBER(v_hora_fin) THEN
            v_fec_operacion := pag_cal.FU_OBT_FEC_HABIL(v_fec_operacion + 1,1,1);
            -- cambiamos la fecha de pago en el pendiente
            paw_bce.pr_act_fec_pag_pendiente(p_mov_pendiente.nro_documento, p_mov_pendiente.cod_per_principal, to_char(v_fec_operacion, 'DD/MM/YYYY'));
            -- modificamos la fecha valor
            UPDATE ge_snp_transferencias s
               SET s.fec_valor = v_fec_operacion
             WHERE s.nro_referencia = p_mov_pendiente.referencia;
         END IF;
      END IF;
 end if;

      v_tra_interbancaria := paw_bel.fu_transferenciaInterbancaria( p_sesion,
                                                             p_cod_canal,
                                                             'A',
                                                             NULL, -- p_codigoSwift
                                                             p_mov_pendiente.nro_cta_contra, --p_numeroCuentaCredito
                                                             p_mov_pendiente.nro_cuenta, --p_numeroCuentaDebito
                                                             v_cod_mon_credito, --p_codigoMonedaCredito
                                                             p_mov_pendiente.mto_contra, --p_montoCredito
                                                             v_fec_operacion,
                                                             NULL, --p_cargos
                                                             NULL, --p_numeroDocumentoCredito
                                                             NULL, --p_nombreBeneficiario
                                                             NULL, --p_direccionBeneficiario
                                                             nvl(v_nro_pre_pactado, 0), --p_numeroContrato
                                                             p_mov_pendiente.descripcion, --p_concepto
                                                             NULL, --p_numeroIp
                                                             NULL, --p_tipoMensaje
                                                             NULL, --p_tipoDocumentoBeneficiario
                                                             p_mov_pendiente.referencia, --p_numeroReferencia
                                                             p_mov_pendiente.monto, --p_montoDebito
                                                             p_mov_pendiente.cotizacion, --p_cotizacionDebito
                                                             p_mov_pendiente.cot_contra, --p_cotizacionCredito
                                                             NULL,
                                                             NULL,
                                                             p_mov_pendiente.tip_pago);

      p_retorno.error                := v_tra_interbancaria.error;
      p_retorno.nombreRespuesta      := v_tra_interbancaria.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_tra_interbancaria.descripcionRespuesta;
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_tra_interbancaria.numeroDocumento, G_NUMBER);
   END;
   --
   PROCEDURE lp_aut_can_snp(p_sesion        IN VARCHAR2,
                            p_cod_canal     IN VARCHAR2,
                            p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                            p_retorno       IN OUT typ_mapa) IS
      v_can_tra_interbancaria typ_cancelarTransferenciaSnp;
   BEGIN
      v_can_tra_interbancaria := paw_bel.fu_cancelarTransferenciaSnp(p_sesion,
                                                                     p_cod_canal,
                                                                     'A',
                                                                     p_mov_pendiente.referencia);
      p_retorno.error                := v_can_tra_interbancaria.error;
      p_retorno.nombreRespuesta      := v_can_tra_interbancaria.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_can_tra_interbancaria.descripcionRespuesta;
   END;
   --
   PROCEDURE lp_aut_tra_tercero(p_sesion        IN VARCHAR2,
                                p_cod_canal     IN VARCHAR2,
                                p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                p_retorno       IN OUT typ_mapa) IS
      v_transferencia typ_transferenciaban;
   BEGIN
      v_transferencia := paw_bel.fu_transferenciasTerceros(p_sesion,
                                   p_cod_canal,
                                   p_mov_pendiente.nro_cuenta, -- cuenta debito
                                   p_mov_pendiente.monto,      -- monto de la operacion
                                   p_mov_pendiente.nro_cta_contra, -- cuenta credito
                                   NULL, -- cod_mon_credito
                                   'A', -- autorizar
                                   p_mov_pendiente.dato, -- documento credito
                                   p_mov_pendiente.dato2, -- concepto
                                   nvl(p_mov_pendiente.referencia, 0), --nro_contrato
                                   NULL, NULL);
      p_retorno.error := v_transferencia.error;
      p_retorno.nombreRespuesta      := v_transferencia.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_transferencia.descripcionRespuesta;
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_transferencia.nroDocumento, G_NUMBER);
   END;
   --
   PROCEDURE lp_aut_tra_gnb(p_sesion        IN VARCHAR2,
                            p_cod_canal     IN VARCHAR2,
                            p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                            p_retorno       IN OUT typ_mapa) IS
      v_transferencia   typ_transferenciaban;
      v_nom_beneficiario VARCHAR2(100);
   BEGIN 
      v_nom_beneficiario := fuw_nom_cre_tra_gnb(p_mov_pendiente.nro_documento, p_mov_pendiente.cod_per_principal);
      v_transferencia := paw_bel.fu_transferenciaGnb(p_sesion,
                                   p_cod_canal,
                                   p_mov_pendiente.nro_cuenta, -- cuenta debito
                                   p_mov_pendiente.mto_contra,      -- monto de la operacion
                                   p_mov_pendiente.nro_cta_contra, -- cuenta credito
                                   p_mov_pendiente.dato2, -- cod_mon_credito
                                   'A', -- autorizar
                                   p_mov_pendiente.dato, -- documento credito
                                   p_mov_pendiente.descripcion, -- concepto
                                   nvl(p_mov_pendiente.referencia, 0), --nro_contrato
                                   v_nom_beneficiario,
                                   NULL, NULL);
      p_retorno.error                := v_transferencia.error;
      p_retorno.nombreRespuesta      := v_transferencia.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_transferencia.descripcionRespuesta;
      -- nro usado para enviar despues a GNBPY a traves del consumer-api
      paw_uti.pr_add_value(p_retorno.datosAdicionales, 'NRO_TRANSACCION', rpad(v_transferencia.nroDocumento, 15, ' ')
         ||' '||p_mov_pendiente.nro_cuenta||' '||v_transferencia.nombreCtaDebito, G_STRING);
      paw_uti.pr_add_value(p_retorno.datosAdicionales, 'NRO_CUENTA', p_mov_pendiente.nro_cta_contra, G_STRING);
      paw_uti.pr_add_value(p_retorno.datosAdicionales, 'NRO_DOCUMENTO',  p_mov_pendiente.dato, G_STRING);
      paw_uti.pr_add_value(p_retorno.datosAdicionales, 'MONTO', paw_uti.lf_for_money(p_mov_pendiente.mto_contra), G_NUMBER);
      paw_uti.pr_add_value(p_retorno.datosAdicionales, 'COD_MONEDA', substr(trim(p_mov_pendiente.dato2), 1, 3), G_STRING);
      paw_uti.pr_add_value(p_retorno.datosAdicionales, 'CTA_DEBITO', p_mov_pendiente.nro_cuenta, G_STRING);
   END;
   --
   PROCEDURE lp_aut_sol_chequera(p_sesion        IN VARCHAR2,
                                 p_cod_canal     IN VARCHAR2,
                                 p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                 p_retorno       IN OUT typ_mapa) IS
      v_chequeras typ_mensajeResChequera;
   BEGIN
      v_chequeras := paw_bel.fu_solicitarChequera(p_sesion,
                                                  p_cod_canal,
                                                  p_mov_pendiente.nro_cuenta,  -- cuenta corriente
                                                  substr(p_mov_pendiente.dato, 1, 1), -- tipo chequera
                                                  p_mov_pendiente.referencia, -- cant hojas
                                                  p_mov_pendiente.cantidad,  -- cantidad de chequeras
                                                  'A', -- autorizar
                                                  substr(p_mov_pendiente.dato2, 1, 3), --oficina retencion
                                                  'M', --Mostrador
                                                  NULL, NULL);
      p_retorno.error                := v_chequeras.error;
      p_retorno.nombreRespuesta      := v_chequeras.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_chequeras.descripcionRespuesta;
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_chequeras.nroDocumento, G_NUMBER);
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeusuario(PRO_AUT_SOL_CHEQUERA, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         g_msj_error := SUBSTR(SQLERRM, 1, 1000);
   END;
   --
   PROCEDURE lp_aut_tra_prepactada(p_sesion        IN VARCHAR2,
                                   p_cod_canal     IN VARCHAR2,
                                   p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                   p_retorno       IN OUT typ_mapa) IS

      v_transferencia typ_transferenciaban;
   BEGIN
      v_transferencia := paw_bel.fu_transferenciasConContrato(p_sesion,
                                                              p_cod_canal,
                                                              p_mov_pendiente.nro_cuenta,     -- cuenta debito
                                                              p_mov_pendiente.nro_cta_contra, -- cuenta credito
                                                             'A',               -- autorizar
                                                              to_number(p_mov_pendiente.dato),     -- numero contrato
                                                              NULL, NULL, NULL);
      p_retorno.error                := v_transferencia.error;
      p_retorno.nombreRespuesta      := v_transferencia.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_transferencia.descripcionRespuesta;
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_transferencia.nroDocumento, G_NUMBER);
   END;
   --
   PROCEDURE lp_aut_pag_nomina(p_cod_canal     IN VARCHAR2,
                               p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                               p_retorno       IN OUT typ_mapa) IS
      v_cod_ofi_origen  ba_oficinas.cod_oficina%TYPE;
      v_cant_error      NUMBER(8);
      v_TCreCab         NUMBER;
      v_TCreDet         NUMBER;
      v_TDebDet         NUMBER;
      v_cCreDet         NUMBER;
      v_verificacion_ok VARCHAR2(10);
      v_error           VARCHAR2(4000);
      v_Reprocesa       VARCHAR2(1) := 'N';
      v_secuencia       NUMBER(10) := 1;
      v_nro_secuencia   NUMBER;
      v_cod_tra_padre   ge_transacciones.cod_transaccion%TYPE;
      v_lugar           VARCHAR2(4000);
      v_tip_pro_sueldo  VARCHAR2(1);
      v_pro_con_errores VARCHAR2(1);
      v_monto           ge_movimientos.monto%TYPE;
      v_des_monto       VARCHAR2(100);
      v_dir_correo      ge_par_dinamicos.val_parametro%TYPE;
      v_des_ente        ge_entes.descripcion%TYPE;
      v_fec_actual      DATE := pag_cal.fu_obt_fec_actual(9);
      v_cod_usuario     cj_cajas.cod_usuario%TYPE;
   BEGIN
      v_cod_ofi_origen := fuj_obt_cod_oficina(p_cod_canal);
      v_cod_usuario    := p_mov_pendiente.usu_insercion;

      -- obtenemos la transaccion padre
      v_cod_tra_padre := paw_bel.fu_obt_tra_sueldo(p_mov_pendiente.dato, p_mov_pendiente.tip_pago);

      -- obtenemos el tipo de proceso de sueldo para el ente
      v_tip_pro_sueldo  := paw_bel.fu_obt_tip_pro_sueldo(p_mov_pendiente.dato);
      v_pro_con_errores := nvl(fug_obt_parentes(p_mov_pendiente.dato, 'PRO_CON_ERRORES'), 'N');

      IF TRUNC(TO_DATE(p_mov_pendiente.dato2, 'DD/MM/YYYY')) > TRUNC(p_mov_pendiente.fec_insercion) THEN
         v_tip_pro_sueldo := 'B';
      END IF;

      -- pagos de aguinalo seran Online y Cancelar con errores independientemente de
      -- la configuracion del ente
      IF p_mov_pendiente.tip_pago = 'A' THEN
         v_tip_pro_sueldo  := 'O';
         v_pro_con_errores := 'C';
      END IF;

      IF v_tip_pro_sueldo = 'O' THEN
         pag_sue.pr_ins_ge_pag_sueldo(
                     v_verificacion_ok,
                     p_mov_pendiente.dato,
                     p_mov_pendiente.nro_cuenta,
                     v_cod_tra_padre,
                     nvl(to_date(p_mov_pendiente.dato2, 'DD/MM/YYYY'), v_fec_actual),
                     v_lugar,
                     v_cant_error,
                     v_TCreCab,
                     v_TCreDet,
                     v_TDebDet,
                     v_cCreDet,
                     p_mov_pendiente.referencia,
                     v_cod_usuario, -- v_msj_caja.codigoUsuario
                     nvl(to_date(p_mov_pendiente.dato2, 'DD/MM/YYYY'), v_fec_actual),
                     p_mov_pendiente.tip_pago);

         IF nvl(v_Cant_Error, 0) <> 0 THEN
            SELECT SUM(monto)
              INTO v_monto
              FROM ge_pag_sueldos_tmp
             WHERE cod_ente = p_mov_pendiente.dato
               AND usu_insercion = v_cod_usuario -- v_msj_caja.codigoUsuario
               AND trunc(fec_insercion) = v_fec_actual
               AND tipo = 'C'
               AND nro_archivo = p_mov_pendiente.referencia;
            -- verificamos si el ente puede procesar pagos con error
            IF NVL(v_monto, 0) <> NVL(v_TDebDet, 0) AND v_pro_con_errores = 'C' THEN
               paw_uti.pr_mensajeusuario(PRO_AUT_ERR_PAG_SALARIO, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            END IF;
         END IF;
         -- no bubo errores
         IF p_retorno.error = 'N' THEN
            v_secuencia := p_mov_pendiente.referencia;
            pag_sue.lp_ins_tabla(
                        p_mov_pendiente.dato,
                        v_lugar,
                        v_secuencia,
                        v_error,
                        p_mov_pendiente.referencia,
                        v_cod_usuario,
                        nvl(to_date(p_mov_pendiente.dato2, 'DD/MM/YYYY'), v_fec_actual),
                        nvl(to_date(p_mov_pendiente.dato2, 'DD/MM/YYYY'), v_fec_actual),
                        'N');

            IF v_error IN ('X', 'S') THEN
               paw_uti.pr_mensajeusuario(PRO_AUT_ERR_INS_DAT_SALARIO, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               g_msj_error:= substr('lp_ins_tabla: [' || v_lugar || ']', 1, 1000);
            ELSE
               v_nro_secuencia := 0;
               pag_cta.pr_set_variables(v_cod_usuario, v_fec_actual, v_cod_tra_padre, 'N', 'N', v_nro_secuencia, NULL, v_cod_ofi_origen, 3, 31);
               v_secuencia := p_mov_pendiente.referencia; -- JIRA 2376
               -- se puede hacer el credito
               pag_sue.pr_act_cred_empleado(
                           v_Reprocesa,
                           p_mov_pendiente.dato,
                           v_secuencia,
                           v_cod_ofi_origen,-- v_msj_caja.codigoOficinaOrigen,
                           nvl(to_date(p_mov_pendiente.dato2, 'DD/MM/YYYY'), v_fec_actual),
                           v_cod_usuario, --v_msj_caja.codigoUsuario,
                           v_lugar,
                           v_error,
                           p_mov_pendiente.tip_pago);
               -- se verifica si no hubo errores en el proceso de acreditacion
               IF v_error IN ('X', 'S') THEN
                  g_msj_error := substr('pr_act_cred_empleado: ['||v_lugar ||']', 1, 1000);
                  paw_uti.pr_mensajeusuario(PRO_AUT_ERR_PAG_SALARIO, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               END IF;
            END IF;
         ELSE
            -- hubo error en la verificacion
            paw_uti.pr_mensajeusuario(PRO_AUT_ERR_PAG_SALARIO, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         END IF;
      ELSE
         v_nro_secuencia := p_mov_pendiente.referencia;
         BEGIN
            INSERT INTO ge_pag_sue_lotes
               (cod_ente, fec_proceso, nro_secuencia, nro_cta_debito, mto_credito, mto_debito, cod_moneda, cantidad, estado, tip_pago, tip_ingreso, tip_proceso)
            VALUES
               (p_mov_pendiente.dato, to_date(p_mov_pendiente.dato2, 'DD/MM/YYYY'), v_nro_secuencia, p_mov_pendiente.nro_cuenta, p_mov_pendiente.monto, p_mov_pendiente.monto, p_mov_pendiente.cod_moneda, p_mov_pendiente.cantidad, 'P', p_mov_pendiente.tip_pago, 'H', v_tip_pro_sueldo);

            -- si la ultima autorizacion se realiza en la fecha de pago llamamos al procedimiento que ejecuta el pago en lotes
            -- con el parametro del ente, para que se realice el pago 'online'
            IF TRUNC(SYSDATE) = TRUNC(TO_DATE(p_mov_pendiente.dato2, 'DD/MM/YYYY')) AND TRUNC(SYSDATE) > TRUNC(p_mov_pendiente.fec_insercion) THEN
               pag_sue.pr_pag_sue_lotes('B', p_mov_pendiente.dato, p_mov_pendiente.referencia);
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               paw_uti.pr_mensajeusuario(PRO_AUT_ERR_SAL_LOTES, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               v_error     := 'S';
               g_msj_error := substr(SQLERRM, 1, 1000);
         END;
      END IF;
      IF v_error IN ('X', 'S') THEN
         IF p_retorno.error = 'N' THEN
            paw_uti.pr_mensajeusuario(PRO_AUT_ERR_PAG_SALARIO, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         END IF;
      ELSIF p_retorno.error = 'N' THEN
         BEGIN
            BEGIN
               v_dir_correo := nvl(fug_obt_pardinamico('SUE_DIR_CORREO'), fug_obt_pardinamico('CAM_MAR_PAG_NOM'));
            EXCEPTION
               WHEN OTHERS THEN
                  v_dir_correo := fug_obt_pardinamico('CAM_MAR_PAG_NOM');
            END;

            v_des_ente := fue_obt_nom_ente(p_mov_pendiente.dato);
            IF NVL(v_monto, 0) <> NVL(V_TDEBDET, 0) AND v_pro_con_errores = 'N' THEN
               v_des_monto := 'Monto: ' || paw_uti.lf_for_money(nvl(V_TDEBDET, p_mov_pendiente.monto), 16) || chr(10);
               -- obtenemos los registros con error para mostrar en el detalle
               -- TODO:
               -- lp_obt_sue_errores(mp.dato, mp.referencia, v_retorno.detalles.listaDetalleSalario);
            ELSE
               v_des_monto := 'Monto   : ' || paw_uti.lf_for_money(p_mov_pendiente.monto, 16);
            END IF;

            IF TRUNC(to_date(p_mov_pendiente.dato2, 'DD/MM/YYYY')) = TRUNC(SYSDATE) THEN
               it_mail.mail(fug_obt_dir_correo, v_dir_correo, 'Pago de Sueldos Confirmado', 'Pago de Sueldos ingresado por HomeBanking ha sido confirmado por el Cliente ' || chr(10) ||
                           'Codigo  : ' || p_mov_pendiente.dato || chr(10) ||
                           'Empresa : ' || v_des_ente || chr(10) ||
                           v_des_monto || chr(10)
                           || 'Cantidad: ' || to_char(p_mov_pendiente.cantidad) || chr(10) ||
                            'Atentamente. ');
            ELSE
               it_mail.mail(fug_obt_dir_correo, v_dir_correo, 'Pago de Sueldos Autorizado', 'Pago de Sueldos ingresado con fecha Futura por HomeBanking'
                           || chr(10) ||  'Codigo  : ' || p_mov_pendiente.dato || chr(10) ||
                            'Empresa : ' || v_des_ente || chr(10) ||
                            v_des_monto || chr(10) ||
                            'Cantidad: ' || to_char(p_mov_pendiente.cantidad) || chr(10) ||
                            'Fecha de pago: ' || p_mov_pendiente.dato2 || chr(10) ||
                            'Atentamente. ');
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               g_msj_error := substr(g_msj_error||', it_mail: ['||SQLERRM||']', 1, 1000);
         END;
      END IF;
   END;
   --
   PROCEDURE lp_aut_proveedores(p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                p_retorno       IN OUT typ_mapa) IS
      v_fec_pago1   DATE;
      v_est_periodo ge_snp_horarios.estado%TYPE;
      v_cam_fecha   BOOLEAN;
      v_fec_snp_hor DATE;
      v_cantidad    NUMBER;
      v_error       VARCHAR2(4000);
      v_des_ente    ge_entes.descripcion%TYPE;
      v_err_pago    VARCHAR2(2) := '00';
      v_hora_fin    ge_snp_horarios.hor_fin%TYPE;
      v_hora_pro    ge_snp_horarios.hor_fin%TYPE;
      v_nro_archivo NUMBER;
   BEGIN
     
      v_fec_pago1   := TRUNC(to_date(substr(p_mov_pendiente.dato2, 1, 10), 'DD/MM/YYYY'));
      v_nro_archivo := p_mov_pendiente.referencia;
      
      -- verificar datos temporales
      pag_prv.PR_VER_DAT_TMP(p_mov_pendiente.dato, v_fec_pago1, NULL, v_error, 'S', p_mov_pendiente.nro_documento, p_mov_pendiente.nro_cuenta, v_nro_archivo, p_mov_pendiente.fec_insercion);
      IF v_error IS NOT NULL THEN
         IF instr(v_error, 'Horario SIPAP Cerrado') > 0 THEN
            paw_uti.pr_mensajeUsuario(PRO_ERR_SIPAP, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         ELSE
            paw_uti.pr_mensajeusuario(PRO_AUT_ERR_DAT_PROVEEDORES, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         END IF;
         g_msj_error := g_msj_error || ', PRV-ERR:[' || SUBSTR(v_error, 1, 150)||']';
      ELSE
         BEGIN
            v_des_ente := fue_obt_nom_ente(p_mov_pendiente.dato);
            IF v_fec_pago1 = trunc(SYSDATE) THEN
               pag_prv.PR_PRO_PAGO(to_number(p_mov_pendiente.dato), p_mov_pendiente.nro_documento, v_err_pago);
               IF v_err_pago <> '00' THEN
                  paw_uti.pr_mensajeusuario(PRO_AUT_ERR_PAG_PROVEEDORES, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  g_msj_error := g_msj_error || ', pr_pro_pago:[' || SUBSTR(v_err_pago, 1, 100)||']';
               ELSE
                  -- controlamos el horario sipap
                  v_est_periodo := pas_snp.fu_obt_est_horario('103', '001', '002');
                  IF v_est_periodo <> 'A' THEN -- hora sipap cerrada
                     v_fec_snp_hor := pag_prv.fu_obt_fec_snp(1);

                     -- si llego hasta aca es porque el lote no es mixto
                     IF v_fec_snp_hor = v_fec_pago1 THEN
                        -- si se cambia la fecha hay que ver si hay monedas distintas
                        v_cantidad := pag_prv.fu_obt_can_ope_cambio(p_mov_pendiente.dato, v_fec_pago1, p_mov_pendiente.cod_moneda, v_nro_archivo);
                        IF v_cantidad > 0 THEN -- hora cerrada no permite operacion de cambio
                           paw_uti.pr_mensajeusuario(PRO_ERR_SIPAP, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                        ELSE
                           v_hora_fin := paw_bas.fu_obt_hor_fin_snp(1);
                           v_hora_pro := TO_CHAR(SYSDATE,'HH24MI');
                           -- DDSI-153 Se valida el horario sipap para cambiar o no la fecha.
                           IF TO_NUMBER(v_hora_pro) >= TO_NUMBER(v_hora_fin) THEN
                              -- se cambia fecha de pago por hora cerrada, solo pagos SIPAP si llego hasta aca
                              v_cam_fecha := pag_prv.fu_cam_fec_pago(p_mov_pendiente.dato, v_fec_pago1, v_nro_archivo);
                           END IF;
                        END IF;
                     END IF;
                  END IF;
               END IF;
            ELSE
               v_cantidad := pag_prv.fu_obt_can_ope_cambio(p_mov_pendiente.dato, v_fec_pago1, p_mov_pendiente.cod_moneda, v_nro_archivo);
               IF v_cantidad > 0 THEN -- hora cerrada no permite operacion de cambio
                  paw_uti.pr_mensajeusuario(PRO_ERR_SIPAP, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               ELSE 
                  it_mail.mail(fug_obt_dir_correo, fug_obt_pardinamico('SUE_DIR_CORREO'),
                                    'Pago a Proveedores en Fecha Futura',
                                    'Pago a Proveedores ingresado por el HomeBanking ' || chr(10) || chr(10) ||
                                    'Codigo  : ' || p_mov_pendiente.dato || chr(10) ||
                                    'Empresa : ' || v_des_ente || chr(10) ||
                                    'Monto   : ' || paw_uti.lf_for_money(p_mov_pendiente.monto, 16) || chr(10) ||
                                    'Cantidad: ' || to_char(p_mov_pendiente.cantidad) || chr(10) ||
                                    'Fecha de Pago: ' || to_char(v_fec_pago1, 'dd/mm/yyyy') || chr(10) || chr(10) ||
                                    'Atentamente. ');
               END IF;
            END IF;
            IF p_retorno.error = 'N' THEN
               v_error := NULL;
               pag_prv.pr_pro_pag_snp (p_mov_pendiente.dato, user, v_error, v_fec_pago1, v_nro_archivo);
               IF v_error IS NOT NULL THEN
                  paw_uti.pr_mensajeusuario(PRO_AUT_ERR_PAG_PROVEEDORES, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  g_msj_error := g_msj_error || ', pr_pro_pag_snp:[' || SUBSTR(v_error, 1, 150)||']';
               ELSE
                  IF v_fec_pago1 = TRUNC(SYSDATE) THEN
                     it_mail.mail(fug_obt_dir_correo, fug_obt_pardinamico('SUE_DIR_CORREO'),
                                       'Pago a Proveedores en Linea',
                                       'Pago a Proveedores ingresado por el HomeBanking ' || chr(10) || chr(10) ||
                                       'Codigo  : ' || p_mov_pendiente.dato || chr(10) ||
                                       'Empresa : ' || v_des_ente || chr(10) ||
                                       'Monto   : ' || paw_uti.lf_for_money(p_mov_pendiente.monto, 16) || chr(10) ||
                                       'Cantidad: ' || to_char(p_mov_pendiente.cantidad) || chr(10) ||
                                       'Fecha de Pago: ' || to_char(v_fec_pago1, 'dd/mm/yyyy') || chr(10) || chr(10) ||
                                       'Atentamente. ');
                  END IF;
               END IF;
            END IF;
            IF p_retorno.error = 'N' THEN
               pag_prv.PR_ELI_PROV_TMP(p_mov_pendiente.dato, p_mov_pendiente.fec_insercion, v_nro_archivo);
               pag_prv.PR_ELI_FAC_TMP(p_mov_pendiente.dato, p_mov_pendiente.fec_insercion, v_nro_archivo);
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               g_msj_error := substr(g_msj_error || ', ORA-ERR:['||SQLERRM||']', 1, 1000);
               paw_uti.pr_mensajeusuario(PRO_AUT_ERR_PAG_PROVEEDORES, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         END;
      END IF;
   END;
   --
   PROCEDURE lp_aut_gourmet(p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                            p_retorno       IN OUT typ_mapa) IS
   BEGIN
     -- se actualizan los datos en el temporal
     UPDATE ta_acr_gourmet_tmp
        SET estado = 'C', fec_proceso = trunc(sysdate)
      WHERE cod_ente = p_mov_pendiente.dato2
        AND nro_archivo = p_mov_pendiente.dato
        AND trunc(fec_insercion) = trunc(sysdate);
     --Se invoca al proceso que realiza las acreditaciones online
     prt_gen_acr_gourmet(p_mov_pendiente.dato, p_mov_pendiente.dato2);
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         g_msj_error := SUBSTR(SQLERRM, 1, 1000);
   END;
   --
   PROCEDURE lp_aut_tra_internacional(p_sesion        IN VARCHAR2,
                                      p_cod_canal     IN VARCHAR2,
                                      p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                      p_retorno       IN OUT typ_mapa) IS
      v_transferencia        typ_transferenciaban;
      v_nom_beneficiario     lc_transferencias.nom_beneficiario%TYPE;
      v_dir_beneficiario     lc_transferencias.dir_beneficiario%TYPE;
      v_nro_cta_referencia   lc_transferencias.nro_cta_referencia%TYPE;
      v_nom_banco            lc_transferencias.nom_banco%TYPE;
      v_cod_pais             ba_paises.cod_pais%TYPE;
      v_cod_ciudad           ba_ciudades.cod_ciudad%TYPE;
      v_cod_bco_corresponsal lc_transferencias.cod_bco_corresponsal%TYPE;
      v_nom_bco_corresponsal lc_transferencias.nom_bco_cor_contra%TYPE;
      v_swi_bco_corresponsal lc_transferencias.cod_swi_bco_contra%TYPE;
      v_pai_bco_corresponsal lc_transferencias.cod_pai_bco_contra%TYPE;
      v_ciu_bco_corresponsal lc_transferencias.cod_ciu_bco_contra%TYPE;
      v_cod_mon_credito      ba_monedas.cod_moneda%TYPE;
      v_nro_contrato         lc_ope_pendientes.nro_diario%TYPE;
      v_tip_cargo            VARCHAR2(3);
      v_plazo                NUMBER(3);
      v_tip_motivo           lc_transferencias.tip_motivo%TYPE;
      v_tip_fondo            lc_transferencias.tip_fondo%TYPE;
      v_tip_financiacion     lc_transferencias.tip_financiacion%TYPE;
      v_cod_swift            lc_transferencias.cod_swi_banco%TYPE;
      v_ref_beneficiario     lc_transferencias.referencia%TYPE;
      v_observacion          lc_transferencias.observacion%TYPE;
      v_cod_pai_beneficiario lc_transferencias.cod_pai_beneficiario%TYPE;
      v_cod_ciu_beneficiario lc_transferencias.cod_ciu_beneficiario%TYPE;
      v_parametros           bw_movimientos.parametros%TYPE;
      v_ord_pago             VARCHAR2(20);
      v_indice               NUMBER := 1;
   BEGIN
      -- obtenemos parametros adicionales
      SELECT observacion, parametros
        INTO v_observacion, v_parametros
        FROM bw_movimientos
       WHERE nro_documento = p_mov_pendiente.nro_documento
         AND trunc(fec_hora) = trunc(p_mov_pendiente.fec_hora)
         AND cod_per_principal = p_mov_pendiente.cod_per_principal
         AND cod_tip_mensaje = p_mov_pendiente.cod_tip_mensaje;

      v_nom_beneficiario := TRIM(substr(v_parametros, v_indice, 120)); v_indice := v_indice + 120;
      v_dir_beneficiario := TRIM(substr(v_parametros, v_indice, 100)); v_indice := v_indice + 100;
      v_nom_banco := TRIM(substr(v_parametros, v_indice, 100)); v_indice := v_indice + 100;
      v_nom_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 100)); v_indice := v_indice + 100;
      v_nro_cta_referencia := TRIM(substr(v_parametros, v_indice, 30)); v_indice := v_indice + 30;
      v_cod_pais := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
      v_cod_ciudad := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
      v_cod_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
      v_pai_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
      v_cod_mon_credito := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
      v_nro_contrato := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 10;
      v_tip_cargo := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
      v_plazo := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
      v_tip_motivo := TRIM(substr(v_parametros, v_indice, 2)); v_indice := v_indice + 5;
      v_tip_fondo := TRIM(substr(v_parametros, v_indice, 2)); v_indice := v_indice + 5;
      v_tip_financiacion := TRIM(substr(v_parametros, v_indice, 2)); v_indice := v_indice + 5;
      v_cod_swift := TRIM(substr(v_parametros, v_indice, 20)); v_indice := v_indice + 20;
      v_cod_pai_beneficiario := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
      v_cod_ciu_beneficiario := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
      v_ref_beneficiario := TRIM(substr(v_parametros, v_indice, 300)); v_indice := v_indice + 300;
      v_swi_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 20)); v_indice := v_indice + 20;
      v_ciu_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 3));  v_indice := v_indice + 3;
      v_ord_pago := TRIM(substr(v_parametros, v_indice, 20));

      SELECT decode(v_nro_contrato, 0, NULL, v_nro_contrato),
             decode(v_cod_bco_corresponsal, 0, NULL, v_cod_bco_corresponsal),
             decode(v_cod_pai_beneficiario, 0, NULL, v_cod_pai_beneficiario),
             decode(v_cod_ciu_beneficiario, 0, NULL, v_cod_ciu_beneficiario),
             decode(v_pai_bco_corresponsal, 0, NULL, v_pai_bco_corresponsal),
             decode(v_ciu_bco_corresponsal, 0, NULL, v_ciu_bco_corresponsal)
        INTO v_nro_contrato, v_cod_bco_corresponsal, v_cod_pai_beneficiario,
             v_cod_ciu_beneficiario, v_pai_bco_corresponsal, v_ciu_bco_corresponsal
        FROM DUAL;

      v_transferencia := paw_bel.fu_transferenciaInternacional
                                           (p_sesion,
                                            p_cod_canal,
                                            'A', -- modo
                                            v_nom_beneficiario,
                                            v_dir_beneficiario,
                                            v_nro_cta_referencia, -- p_cuentaCredito
                                            p_mov_pendiente.dato2, -- p_codigoBanco
                                            v_nom_banco, --p_nombreBanco
                                            v_cod_swift,  -- p_codigoSwift
                                            v_cod_pais,
                                            v_cod_ciudad,
                                            v_cod_bco_corresponsal, --p_codBancoCorresponsal
                                            v_nom_bco_corresponsal,
                                            v_swi_bco_corresponsal,
                                            v_ciu_bco_corresponsal,
                                            v_pai_bco_corresponsal,
                                            v_cod_mon_credito,
                                            p_mov_pendiente.mto_contra, -- p_montoCredito
                                            v_nro_contrato,
                                            p_mov_pendiente.nro_cuenta, -- p_cuentaDebito
                                            v_tip_cargo,
                                            v_plazo,
                                            v_tip_motivo,
                                            v_tip_fondo,
                                            v_tip_financiacion,
                                            v_ref_beneficiario,
                                            v_observacion,
                                            NULL,
                                            NULL,
                                            v_cod_pai_beneficiario,
                                            v_cod_ciu_beneficiario,
                                            NULL,
                                            NULL,
                                            p_mov_pendiente.referencia,
                                            v_ord_pago);
      p_retorno.error                := v_transferencia.error;
      p_retorno.nombreRespuesta      := v_transferencia.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_transferencia.descripcionRespuesta;
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_transferencia.nroDocumento, G_NUMBER);
   EXCEPTION
      WHEN OTHERS THEN
         g_msj_error := substr(SQLERRM, 1, 1000);
         paw_uti.pr_mensajeusuario(paw_uti.MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
   END;
   --
   PROCEDURE lp_aut_sof_enroll(p_cod_persona IN ba_personas.cod_persona%TYPE,
                               p_cod_empresa IN ba_personas.cod_persona%TYPE,
                               p_retorno       IN OUT typ_mapa) IS
      v_sof_data typ_mensajerespuesta;
   BEGIN
      v_sof_data := paw_seg.fu_act_est_softoken(p_cod_persona, p_cod_empresa, 'A');
      IF v_sof_data.error = 'N' THEN
         -- notificamos a la empresa si no hubo errores
         paw_otp.pr_SoftokenNotifEmpre(p_cod_empresa, p_cod_persona, 'A');
      END IF;
      p_retorno.error                := v_sof_data.error;
      p_retorno.nombreRespuesta      := v_sof_data.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_sof_data.descripcionRespuesta;
   END;
   --
   PROCEDURE lp_aut_recaudaciones(p_cod_canal     IN VARCHAR2,
                                  p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                  p_retorno       IN OUT typ_mapa) IS
      v_fec_operacion     DATE := to_date(substr(p_mov_pendiente.dato2, 1, 10), 'dd/mm/yyyy');
      v_hor_cierre        VARCHAR2(19) := to_char(sysdate,'dd/mm/yyyy')||' '||nvl(substr(trim(fug_obt_pardinamico('HOR_CIE_PAG_SER_RECAUDACION')),1,5),'18:00')||':00';
      v_cam_fec_operacion DATE;
      v_cam_nro_archivo   NUMBER;
      v_nro_archivo       ge_pag_recaudaciones.nro_archivo%TYPE := p_mov_pendiente.referencia;
      v_tip_proceso       VARCHAR2(1) := nvl(fug_obt_parentes(p_mov_pendiente.dato, 'TIP_PRO_RECAUDACION'), 'O');
      v_cod_ofi_origen    cj_cajas.cod_oficina%TYPE;
      v_error             VARCHAR2(4000);
      v_ret               NUMBER;
   BEGIN
      v_cod_ofi_origen := fuj_obt_cod_oficina(p_cod_canal);
      IF v_fec_operacion = trunc(SYSDATE) THEN
         IF SYSDATE > to_date(v_hor_cierre, 'dd/mm/yyyy hh24:mi:ss') THEN
            -- se cambia la fecha de proceso por autorizacion fuera del horario de corte
            v_cam_fec_operacion := pag_cal.fu_obt_fec_habil(v_fec_operacion + 1, 1, v_cod_ofi_origen);
            -- se reverifica el numero de archivo por cambio de fecha de operacion
            v_cam_nro_archivo := pag_rec.FU_OBT_SIG_NUM_ARCHIVO(p_mov_pendiente.dato, v_cam_fec_operacion);
            -- se cambia la fecha operacion y nro_secuencia del proceso pendiente
            UPDATE bw_mov_pendientes p
               SET p.dato2 = to_char(v_cam_fec_operacion, 'dd/mm/yyyy'),
                   p.referencia = v_cam_nro_archivo
             WHERE p.nro_documento = p_mov_pendiente.nro_documento
               AND p.cod_per_principal = p_mov_pendiente.cod_per_principal
               AND p.cod_tip_mensaje = p_mov_pendiente.cod_tip_mensaje
               AND trunc(p.fec_insercion) = trunc(SYSDATE);
            -- se cambia la fecha operacion y nro_secuencia de los detalles
            UPDATE ge_pag_recaudaciones_tmp t
               SET t.fec_operacion = v_cam_fec_operacion,
                   t.nro_archivo = v_cam_nro_archivo
             WHERE t.cod_ente = p_mov_pendiente.dato
               AND t.fec_operacion = v_fec_operacion
               AND t.nro_archivo = v_nro_archivo
               AND trunc(t.fec_insercion) = trunc(SYSDATE);
            -- actualizamos los nuevos valores de nro_archivo y fecha operacion
            v_fec_operacion := v_cam_fec_operacion;
            v_nro_archivo := v_cam_nro_archivo;
         END IF;
      END IF;
      pag_rec.pr_ins_ge_pag_recaudaciones(p_mov_pendiente.dato, v_nro_archivo, v_fec_operacion, v_error);
      IF v_error IS NOT NULL THEN
         paw_uti.pr_mensajeusuario(paw_uti.MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         g_msj_error := substr('pag_rec:[' || v_error || ']', 1, 1000);
      ELSE
         v_ret := pag_rec.fu_eli_temporal(p_mov_pendiente.dato, v_nro_archivo, v_fec_operacion) +
                  pag_rec.fu_eli_errores(p_mov_pendiente.dato, v_nro_archivo, v_fec_operacion);
         pag_rec.pr_val_temporal(p_mov_pendiente.dato, v_fec_operacion, v_nro_archivo, 'S');
         v_ret := v_ret + pag_rec.fu_act_est_recaudacion(p_mov_pendiente.dato, v_nro_archivo, v_fec_operacion, 'A');
      END IF;
      -- si es online y no hay errores, procesar
      IF v_fec_operacion = trunc(SYSDATE) AND p_retorno.error = 'N' AND v_tip_proceso = 'O' THEN
         pag_rec.PR_COB_SER_REC('N', NULL, p_mov_pendiente.dato);
         IF v_error IS NOT NULL THEN
            paw_uti.pr_mensajeusuario(PRO_AUT_ERR_RECAUDACIONES, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            g_msj_error := substr('pag_rec:[' || v_error || ']', 1, 1000);
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         g_msj_error := SUBSTR(SQLERRM, 1, 100);
         paw_uti.pr_mensajeusuario(paw_uti.MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
   END;
   --
   PROCEDURE lp_aut_alt_empleados(p_sesion        IN VARCHAR2,
                                  p_cod_canal     IN VARCHAR2,
                                  p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                  p_retorno       IN OUT typ_mapa) IS
      v_alta typ_altaEmpleados;
   BEGIN
      v_alta := paw_bel.fu_altaEmpleados(p_sesion,
                                         p_cod_canal,
                                         'A',
                                         p_mov_pendiente.cod_moneda,
                                         p_mov_pendiente.dato2,
                                         p_mov_pendiente.cantidad,
                                         NULL, NULL, NULL,
                                         p_mov_pendiente.nro_documento);
      p_retorno.error                := v_alta.error;
      p_retorno.nombreRespuesta      := v_alta.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_alta.descripcionRespuesta;
      paw_uti.pr_add_value(p_retorno.datosAdicionales, DOC_NUMBER_TAG, v_alta.numeroDocumento, G_NUMBER);

   END;
   --
   PROCEDURE lp_aut_act_tok_digital(p_sesion        IN VARCHAR2,
                                    p_cod_canal     IN VARCHAR2,
                                    p_mov_pendiente IN bw_mov_pendientes%ROWTYPE,
                                    p_retorno       IN OUT typ_mapa) IS
      v_numero typ_regceltoken;
   BEGIN
      v_numero := paw_bel.fu_asi_nro_token(p_sesion,
                                         p_cod_canal,
                                         'A',
                                         p_mov_pendiente.dato,
                                         NULL, NULL,
                                         p_mov_pendiente.cod_per_ingreso);
      p_retorno.error                := v_numero.error;
      p_retorno.nombreRespuesta      := v_numero.nombreRespuesta;
      p_retorno.descripcionRespuesta := v_numero.descripcionRespuesta;

   END;
   -- Se comenta la funcion porque requiera objetos de sipap/spi
   -- Funcion para autorizar una operacion
   /*FUNCTION fu_autorizarOperacion(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                                  p_cod_empresa     IN ba_personas.cod_persona%TYPE,
                                  p_cod_canal       IN cj_cajas.nro_caja%TYPE,
                                  p_id_session      IN VARCHAR2,
                                  p_nro_documento   IN bw_mov_pendientes.nro_documento%TYPE) RETURN typ_mapa IS
      -- datos recibidos
      v_cod_operacion     VARCHAR2(3) := '023';
      v_retorno           typ_mapa := typ_mapa();
      v_dat_adicional     typ_listaclavevalor := typ_listaclavevalor();
      v_det_pendiente     typ_detallependiente := typ_detallependiente();
      v_msj_respuesta     typ_mensajerespuesta;
      v_tag               bw_bitacoras.tipo%TYPE;
      v_cod_per_empresa   ba_personas.cod_persona%TYPE := substr(p_cod_empresa, 1, 10);
      rg_bmpen            bw_mov_pendientes%ROWTYPE;
      v_msj_bitacora      VARCHAR2(800) := substr('authLote, nroDoc:'||p_nro_documento, 1, 800);
      v_resul_spi         ge_spi_transferencias.error%type;
      
   BEGIN
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_session, v_cod_operacion, p_cod_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ENTRADA);
      -- validamos el mov. pendiente, debe estar agendado
      v_msj_respuesta := fu_val_doc_autorizacion(p_nro_documento, v_cod_per_empresa, p_cod_persona, p_cod_canal, 'E', v_det_pendiente);
      v_retorno.error := v_msj_respuesta.error;
      v_retorno.nombreRespuesta := v_msj_respuesta.nombreRespuesta;
      v_retorno.descripcionRespuesta := v_msj_respuesta.descripcionRespuesta;

      IF v_retorno.error = 'S' THEN
         paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_session, v_cod_operacion, v_cod_per_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
         RETURN v_retorno;
      END IF;
      IF lf_obt_det_pendiente(p_cod_empresa, p_nro_documento, 'E', rg_bmpen) < 0 THEN
         paw_uti.pr_mensajeusuario(PRO_AUT_DOC_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_session, v_cod_operacion, v_cod_per_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
         RETURN v_retorno;
      END IF;
      -- establecer modo autorizacion
      paw_bel.pr_set_autorizacion;
      -- dependiendo del documento, se deberia agregar datos especificos de la operacion en este campo
      v_retorno.datosAdicionales := v_dat_adicional;
      -- procesamos el mensaje
      CASE rg_bmpen.cod_tip_mensaje
         WHEN '030' THEN
            lp_aut_tra_propia(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '031' THEN
            lp_aut_pag_prestamo(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '032' THEN
            lp_aut_pag_tarjeta(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '033' THEN
            lp_aut_pag_aduana(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '034' THEN
            NULL; -- va por el api de pagos
         WHEN '036' THEN
            lp_aut_tra_snp(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '038' THEN
            lp_aut_can_snp(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '039' THEN
            lp_aut_tra_tercero(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '055' THEN
            lp_aut_tra_gnb(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '060' THEN
            lp_aut_sol_chequera(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '070' THEN
            lp_aut_pag_nomina(p_cod_canal, rg_bmpen, v_retorno);
         WHEN '071' THEN
            lp_aut_gourmet(rg_bmpen, v_retorno);
         WHEN '075' THEN
            lp_aut_proveedores(rg_bmpen, v_retorno);
         WHEN '088' THEN
            NULL; -- va por el api de pagos
         WHEN '090' THEN
            lp_aut_recaudaciones(p_cod_canal, rg_bmpen, v_retorno);
         WHEN '091' THEN
            NULL; -- va por el api de pagos
         WHEN '130' THEN
            lp_aut_alt_empleados(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '150' THEN
            lp_aut_act_tok_digital(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '214' THEN
            lp_aut_tra_prepactada(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '227' THEN
            lp_aut_tra_internacional(p_id_session, p_cod_canal, rg_bmpen, v_retorno);
         WHEN '008' THEN
            lp_aut_sof_enroll(rg_bmpen.cod_per_ingreso, p_cod_empresa, v_retorno);
      END CASE;
      v_retorno.cantidad := v_retorno.datosAdicionales.count;
      IF v_retorno.error = 'N' THEN
         -- se actualiza el estado a confirmado
         v_tag := paw_uti.BITACORA_SALIDA;
         UPDATE bw_mov_pendientes p
            SET p.estado = 'C'
          WHERE p.nro_documento = rg_bmpen.nro_documento
            AND p.cod_per_principal = rg_bmpen.cod_per_principal
            AND p.cod_tip_mensaje = rg_bmpen.cod_tip_mensaje
            AND p.estado = 'E'
            AND p.can_aut_faltantes = 0;
      ELSE
         v_tag := paw_uti.BITACORA_ERROR;
         v_msj_bitacora := substr(v_msj_bitacora||', msg-err: '||g_msj_error, 1, 1000);
      END IF;
      
      if rg_bmpen.cod_tip_mensaje='036'  and rg_bmpen.nro_cta_contra=g_cuenta_spi and rg_bmpen.can_aut_faltantes=0 then
        begin
            v_resul_spi:=pas_spi.fu_envio_spi(rg_bmpen.referencia,rg_bmpen.cod_per_principal,rg_bmpen.nro_documento,p_cod_canal); 
            v_msj_bitacora:=' Resultado de consulta a BCP desde EMA - Nro.Referencia : '||  rg_bmpen.referencia || ' Resultado :'||  v_resul_spi ;
            paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_session, v_cod_operacion, v_cod_per_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_SALIDA);
        exception when others then
            v_msj_bitacora:='Error al consultar A BCP desde EMA - Nro.Referencia '||  rg_bmpen.referencia;
            paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_session, v_cod_operacion, v_cod_per_empresa, v_msj_bitacora || ' ' || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || '] ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);
        end; 
     end if;    

      paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_session, v_cod_operacion, v_cod_per_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), v_tag);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_session, v_cod_operacion, v_cod_per_empresa, v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || '] ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);
         RETURN v_retorno;
   END;
*/
   FUNCTION fu_obt_operaciones(p_cod_persona IN VARCHAR2,
                               p_cod_empresa IN VARCHAR2,
                               p_cod_canal IN VARCHAR2,
                               p_estados IN VARCHAR2,
                               p_id_sesion IN VARCHAR2 DEFAULT NULL) RETURN typ_autorizacionesDelDia IS
      v_cod_operacion  VARCHAR2(3) := '024';
           v_permiso        typ_permisos;
           v_cta_formateada VARCHAR2(16);
           v_retorno        typ_autorizacionesDelDia := typ_autorizacionesDelDia();
           v_lis_detalle    typ_listadetallependiente := typ_listadetallependiente();
           v_detalle        typ_detallePendiente := typ_detallePendiente();
           v_can_detalles   NUMBER := 0;
           v_cod_perfil     VARCHAR2(50);
           v_datAdicionales typ_listaClaveValor := typ_listaClaveValor();
           v_cta_credito    VARCHAR2(17);
           v_nom_cta_credito VARCHAR2(100);
           v_tip_cta_credito VARCHAR2(50);
           --v_claveValor typ_claveValor := typ_claveValor();
           v_cod_mon_local VARCHAR2(3) := pag_gen.FU_OBT_MON_LOCAL;
           v_tip_cotizacion VARCHAR2(1);
           v_cotizacion NUMBER;
           v_cot_contra NUMBER;
           v_estados VARCHAR(20) := NVL(p_estados, 'P');
           v_rango NUMBER := 90; -- TODO: llevar este valor en un par dinamico
           v_cod_per_rechazo BA_PERSONAS.COD_PERSONA%TYPE;
           v_aut_operador VARCHAR2(1);

           v_nom_beneficiario     lc_transferencias.nom_beneficiario%TYPE;
           v_dir_beneficiario     lc_transferencias.dir_beneficiario%TYPE;
           v_nro_cta_referencia   lc_transferencias.nro_cta_referencia%TYPE;
           v_nom_banco            lc_transferencias.nom_banco%TYPE;
           v_cod_pais             ba_paises.cod_pais%TYPE;
           v_cod_ciudad           ba_ciudades.cod_ciudad%TYPE;
           v_cod_bco_corresponsal lc_transferencias.cod_bco_corresponsal%TYPE;
           v_nom_bco_corresponsal lc_transferencias.nom_bco_cor_contra%TYPE;
           v_swi_bco_corresponsal lc_transferencias.cod_swi_bco_contra%TYPE;
           v_pai_bco_corresponsal lc_transferencias.cod_pai_bco_contra%TYPE;
           v_ciu_bco_corresponsal lc_transferencias.cod_ciu_bco_contra%TYPE;
           v_cod_mon_credito      ba_monedas.cod_moneda%TYPE;
           v_nro_contrato         lc_ope_pendientes.nro_diario%TYPE;
           v_tip_cargo            VARCHAR2(3);
           v_plazo                NUMBER(3);
           v_tip_motivo           lc_transferencias.tip_motivo%TYPE;
           v_tip_fondo            lc_transferencias.tip_fondo%TYPE;
           v_tip_financiacion     lc_transferencias.tip_financiacion%TYPE;
           v_cod_swift            lc_transferencias.cod_swi_banco%TYPE;
           v_ref_beneficiario     lc_transferencias.referencia%TYPE;
           v_cod_pai_beneficiario lc_transferencias.cod_pai_beneficiario%TYPE;
           v_cod_ciu_beneficiario lc_transferencias.cod_ciu_beneficiario%TYPE;
           v_ord_pago             VARCHAR2(20);
           v_tkd_admin            VARCHAR2(1);

           v_msj_bitacora      VARCHAR2(800) := substr('estados:'||p_estados, 1, 800);


           CURSOR c_operaciones(p_empresa IN ba_personas.cod_persona%TYPE) IS
              SELECT a.*, fug_cta_formateada(c.cod_modulo, c.cod_modalidad, c.cod_oficina,
                     c.nro_cuenta, c.cod_moneda) cta_formateada, c.cod_modulo, c.cod_modalidad,
                     c.cod_moneda cod_mon_debito
                FROM ge_cuentas c, bw_tip_mensajes b, bw_mov_pendientes a
               WHERE a.cod_per_principal = p_empresa
                 AND c.nro_cuenta = a.nro_cuenta
                 AND a.estado IN (SELECT column_value FROM TABLE (fug_obt_tab_registro(v_estados, ',' )))
                 AND b.cod_tip_mensaje = a.cod_tip_mensaje
                 AND (b.cod_tip_mensaje IN ('070','075') AND TRUNC(SYSDATE - v_rango) <= to_date(a.dato2,'DD/MM/YYYY'))
               UNION
              SELECT a.*, fug_cta_formateada(c.cod_modulo, c.cod_modalidad, c.cod_oficina,
                     c.nro_cuenta, c.cod_moneda) cta_formateada, c.cod_modulo, c.cod_modalidad,
                     c.cod_moneda cod_mon_debito
                FROM ge_cuentas c, bw_tip_mensajes b, bw_mov_pendientes a
               WHERE a.cod_per_principal = p_empresa
                 AND c.nro_cuenta = a.nro_cuenta
                 AND a.estado IN (SELECT column_value FROM TABLE (fug_obt_tab_registro(v_estados, ',' )))
                 AND b.cod_tip_mensaje = a.cod_tip_mensaje
                 AND (b.cod_tip_mensaje NOT IN ('070','075') AND TRUNC(SYSDATE - v_rango) <= TRUNC(a.fec_insercion))
               UNION
                SELECT a.*, null cta_formateada, null, null, null
                  FROM  bw_tip_mensajes b, bw_mov_pendientes a
                 WHERE a.cod_per_principal = p_empresa
                   AND a.estado IN (SELECT column_value FROM TABLE (fug_obt_tab_registro(v_estados, ',' )))
                   AND b.cod_tip_mensaje = a.cod_tip_mensaje
                   AND (b.cod_tip_mensaje IN ('008', '150') AND TRUNC(SYSDATE - 5) <= TRUNC(a.fec_insercion));
        BEGIN
           paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ENTRADA);

           v_cod_perfil := fuw_obt_per_empresa(p_cod_empresa, p_cod_persona);

           v_permiso := paw_seg.fu_obt_permisos(p_cod_empresa, v_cod_perfil, p_cod_canal, v_cod_operacion);
           
           v_tkd_admin := paw_otp.fu_es_aut_softoken(p_cod_persona, p_cod_empresa);

           -- NO EXISTE ESTADO R EN EL CORE, SE REMPLAZA R POR A
           v_estados := REPLACE(v_estados, 'R', 'A');

           FOR op IN c_operaciones(p_cod_empresa)
           LOOP
              IF v_permiso.error = 'S' OR v_permiso.consulta = 'N' THEN
                 CONTINUE;
              END IF;
              IF op.cod_tip_mensaje = '008' AND v_tkd_admin = 'N' THEN
                 CONTINUE;
              END IF;

              -- transferencia sipap
              IF op.cod_tip_mensaje = 036 THEN
                 DECLARE
                    v_concepto VARCHAR2(100);
                 BEGIN
                   if op.nro_cta_contra=g_cuenta_spi then
                       begin
                          select t1.nro_cta_receptor  as cuenta, t1.nom_cli_receptor as nombre, 'Transferencia Interbancaria' as concepto, t1.cod_moneda as moneda
                          INTO v_cta_credito, v_nom_beneficiario, v_concepto, v_cod_mon_credito
                          from ge_spi_transferencias t1
                          WHERE t1.nro_referencia = op.referencia;
                       exception when no_data_found then
                            paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, 'No se pudo encontrar datos SPI en fu_obt_operaciones '|| op.referencia, paw_uti.BITACORA_ERROR);
                       when others then  
                            paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, 'Error al buscar SPI en fu_obt_operaciones '|| op.referencia, paw_uti.BITACORA_ERROR);
                       end;      
                    else
                          select t.nro_cta_beneficiario as cuenta, t.nom_beneficiario as nombre , substr(t.concepto, 0, 100) as concepto, t.cod_moneda as moneda
                          INTO v_cta_credito, v_nom_beneficiario, v_concepto, v_cod_mon_credito
                          from ge_snp_transferencias t
                          WHERE t.nro_referencia = op.referencia;
                   end if;             

                    PAW_UTI.pr_add_value(v_datAdicionales, 'NOM_BENEFICIARIO', v_nom_beneficiario, G_VARCHAR);
                    --
                    PAW_UTI.pr_add_value(v_datAdicionales, 'NRO_CTA_CREDITO', v_cta_credito, G_VARCHAR);
                    --
                    PAW_UTI.pr_add_value(v_datAdicionales, 'COD_MON_CTA_CREDITO', v_cod_mon_credito, G_VARCHAR);
                    --
                    PAW_UTI.pr_add_value(v_datAdicionales, 'CONCEPTO',  op.descripcion, G_VARCHAR);
                 EXCEPTION 
                    WHEN OTHERS THEN
                       CONTINUE;
                 END;
              END IF;

              v_can_detalles := v_can_detalles + 1;
              IF op.cod_modulo = 5 THEN
                 v_cta_formateada := paw_bce.fu_obt_nro_tarjeta(op.nro_cuenta, p_cod_persona, p_cod_empresa);
              ELSE
                 v_cta_formateada := op.cta_formateada;
              END IF;
              v_detalle.numeroDocumento := op.nro_documento;
              v_detalle.fechaHora       := op.fec_hora;
              v_detalle.descripcion     := substr(op.descripcion, 1, 60);
              v_detalle.numeroCuenta    := substr(v_cta_formateada, 1, 17);
              v_detalle.codigoMoneda    := op.cod_moneda;
              v_detalle.monto           := op.monto;
              v_detalle.estado          := op.estado;
              IF op.estado = 'C' AND op.cod_tip_mensaje IN ('088','034') AND op.dato2 IS NULL THEN
                 v_detalle.estado := 'A';
              END IF;
              IF op.cod_per_ingreso IS NOT NULL THEN
                 PAW_UTI.pr_add_value(v_datAdicionales, 'PER_REGISTRO', fue_obt_nom_persona(op.cod_per_ingreso), G_VARCHAR);
              END IF;
              -- buscamos quien anulo la operacion
              IF v_detalle.estado = 'A' THEN
                 v_cod_per_rechazo := fuw_obt_per_autorizacion(op.nro_documento, 'R');
                 -- si se rechazo la operacion, marcamos como R el estado
                 IF v_cod_per_rechazo IS NOT NULL THEN
                    v_detalle.estado := 'R';
                    PAW_UTI.pr_add_value(v_datAdicionales, 'PER_RECHAZO', fue_obt_nom_persona(v_cod_per_rechazo), G_VARCHAR);
                    PAW_UTI.pr_add_value(v_datAdicionales, 'COD_PER_RECHAZO', v_cod_per_rechazo, G_VARCHAR);
                 END IF;
              END IF;
              -- buscamos quien elimino la operacion
              IF v_detalle.estado = 'B' THEN
                 v_cod_per_rechazo := fuw_obt_per_autorizacion(op.nro_documento, 'B');
                 IF v_cod_per_rechazo IS NOT NULL THEN
                    PAW_UTI.pr_add_value(v_datAdicionales, 'PER_ELIMINAR', fue_obt_nom_persona(v_cod_per_rechazo), G_VARCHAR);
                    PAW_UTI.pr_add_value(v_datAdicionales, 'COD_PER_ELIMINAR', v_cod_per_rechazo, G_VARCHAR);
                 END IF;
              END IF;

              IF op.estado = 'P' THEN
                 BEGIN
                    SELECT 'S'
                      INTO v_aut_operador
                      FROM BW_AUTORIZACIONES A
                     WHERE A.ACCION = 'A'
                       AND A.NRO_DOCUMENTO = OP.NRO_DOCUMENTO
                       AND A.COD_PERSONA = p_cod_persona
                       AND ROWNUM = 1;
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       v_aut_operador := 'N';
                    WHEN OTHERS THEN
                       v_aut_operador := 'N';
                 END;
                 IF v_aut_operador IS NOT NULL THEN
                    PAW_UTI.pr_add_value(v_datAdicionales, 'PER_AUTORIZO', v_aut_operador, G_VARCHAR);
                 END IF;
              END IF;
              -- transferencia internacional
              IF op.cod_tip_mensaje = 227 THEN
                 op.cod_moneda := op.cod_mon_debito;
                 pr_obt_dat_tra_internacional(op.nro_documento,
                                              op.fec_hora,
                                              op.cod_per_principal,
                                              v_nom_beneficiario,
                                              v_dir_beneficiario,
                                              v_nro_cta_referencia,
                                              v_nom_banco,
                                              v_cod_pais,
                                              v_cod_ciudad,
                                              v_cod_bco_corresponsal,
                                              v_nom_bco_corresponsal,
                                              v_swi_bco_corresponsal,
                                              v_pai_bco_corresponsal,
                                              v_ciu_bco_corresponsal,
                                              v_cod_mon_credito,
                                              v_nro_contrato,
                                              v_tip_cargo,
                                              v_plazo,
                                              v_tip_motivo,
                                              v_tip_fondo,
                                              v_tip_financiacion,
                                              v_cod_swift,
                                              v_ref_beneficiario,
                                              v_cod_pai_beneficiario,
                                              v_cod_ciu_beneficiario,
                                              v_ord_pago);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'NOM_BENEFICIARIO', v_nom_beneficiario, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'DIR_BENEFICIARIO', v_dir_beneficiario, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'NRO_CTA_CREDITO', v_nro_cta_referencia, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'NOM_BANCO_DESTINO', v_nom_banco, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'COD_PAIS_BAN_DESTINO', v_cod_pais, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'NOM_PAIS_BAN_DESTINO', fue_obt_des_pais(v_cod_pais), G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'SWI_BANCO_DESTINO', v_cod_swift, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'COD_PAIS_BENEFICIARIO',  v_cod_pai_beneficiario, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'NOM_PAIS_BENEFICIARIO', fue_obt_des_pais(v_cod_pai_beneficiario), G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'COD_BANCO_INTERMEDIARIO', v_cod_bco_corresponsal, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'NOM_BANCO_INTERMEDIARIO',  v_nom_bco_corresponsal, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'SWI_BANCO_INTERMEDIARIO',  v_swi_bco_corresponsal, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'COD_PAIS_BAN_INTERMEDIARIO', v_pai_bco_corresponsal,  G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'NOM_PAIS_BAN_INTERMEDIARIO', fue_obt_des_pais(v_pai_bco_corresponsal), G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'MON_CTA_CREDITO', v_cod_mon_credito, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'NRO_CONTRATO', v_nro_contrato, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'TIP_CARGO', v_tip_cargo, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'PLAZO', v_plazo, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'TIP_MOTIVO', v_tip_motivo, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'TIP_FONDO', v_tip_fondo,  G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'TIP_FINANCIACION', v_tip_financiacion, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'REF_BENEFICIARIO', v_ref_beneficiario, G_VARCHAR);
                 PAW_UTI.pr_add_value(v_datAdicionales, 'ORD_PAGO', v_ord_pago, G_VARCHAR);
              END IF;
              v_detalle.autorizacionesRequeridas := op.can_aut_requeridas;
              v_detalle.autorizacionesFaltantes := op.can_aut_faltantes;
              v_detalle.codModulo := op.cod_modulo;
              v_detalle.codTipOperacion := op.cod_tip_mensaje;
              v_detalle.perRegistro := fue_obt_nom_persona(op.cod_per_ingreso);
              v_detalle.etiqueta := op.etiqueta;
              v_detalle.dato := op.dato;
              v_detalle.etiqueta2 := op.etiqueta2;
              v_detalle.dato2 := op.dato2;
              v_detalle.tipPago := op.tip_pago;
              v_detalle.tipoCuenta := paw_bce.fu_tip_cuenta(op.cod_modulo, op.cod_modalidad);
              v_detalle.cantidad := op.cantidad;
              v_lis_detalle.extend;
              PAW_UTI.pr_add_value(v_datAdicionales, 'DESCRIPCION', op.descripcion, G_STRING);

              IF op.nro_cta_contra IS NOT NULL AND op.cod_tip_mensaje NOT IN (227, 036, 055) THEN
                 BEGIN
                    SELECT a.cod_moneda, paw_bce.fu_tip_cuenta(op.cod_modulo, op.cod_modalidad) tip_cuenta,
                           denominacion
                      INTO v_cod_mon_credito, v_tip_cta_credito, v_nom_cta_credito
                      FROM ge_cuentas a
                     WHERE a.nro_cuenta = op.nro_cta_contra;
                    
                    
                    paw_uti.pr_add_value(v_datAdicionales, 'NOM_BENEFICIARIO', v_nom_cta_credito, G_STRING);
                    paw_uti.pr_add_value(v_datAdicionales, 'MON_CTA_CREDITO', v_cod_mon_credito, G_STRING);
                    paw_uti.pr_add_value(v_datAdicionales, 'TIP_CTA_CREDITO', v_tip_cta_credito, G_STRING);
                 EXCEPTION
                   WHEN OTHERS THEN
                      NULL;
                 END;

              END IF;
              
              
              IF op.cod_tip_mensaje = '055' THEN
                 BEGIN
                     v_nom_cta_credito := fuw_nom_cre_tra_gnb(op.nro_documento, op.cod_per_principal);
                     v_cod_mon_credito := substr(trim(op.dato2), 1,  3);
                    
                    paw_uti.pr_add_value(v_datAdicionales, 'NOM_BENEFICIARIO', v_nom_cta_credito, G_STRING);
                    paw_uti.pr_add_value(v_datAdicionales, 'MON_CTA_CREDITO', v_cod_mon_credito, G_STRING);
                    IF fue_obt_des_operacion('055') <> op.descripcion THEN
                       paw_uti.pr_add_value(v_datAdicionales, 'CONCEPTO', op.descripcion, G_STRING);
                    ELSE
                       paw_uti.pr_add_value(v_datAdicionales, 'CONCEPTO', 'Cuenta GNB '|| op.nro_cta_contra, G_STRING); 
                    END IF;
                 EXCEPTION
                   WHEN OTHERS THEN
                      NULL;
                 END;

              END IF;

              PAW_UTI.pr_add_value(v_datAdicionales, 'MTO_CREDITO', op.mto_contra, G_VARCHAR);
              PAW_UTI.pr_add_value(v_datAdicionales, 'CTA_CREDITO',  op.nro_cta_contra, G_VARCHAR);
              IF op.cod_moneda <> v_cod_mon_credito THEN
                 IF op.cotizacion IS NOT NULL OR op.cot_contra IS NOT NULL THEN
                    IF op.cod_moneda <> v_cod_mon_local AND v_cod_mon_credito <> v_cod_mon_local AND
                       op.cod_moneda <> v_cod_mon_credito THEN
                       -- ARBITRAJE
                       v_tip_cotizacion := 'A';
                       v_cotizacion := op.cotizacion;
                       v_cot_contra := op.cot_contra;
                       --
                       PAW_UTI.pr_add_value(v_datAdicionales, 'COT_CONTRA', v_cot_contra, G_VARCHAR);
                       --
                    ELSIF op.cod_moneda = v_cod_mon_local AND v_cod_mon_credito <> v_cod_mon_local THEN
                       -- VENTA
                       v_tip_cotizacion := 'V';
                       v_cotizacion := op.cot_contra;
                    ELSE
                       -- COMPRA
                       v_tip_cotizacion := 'C';
                       v_cotizacion := op.cotizacion;
                    END IF;
                    PAW_UTI.pr_add_value(v_datAdicionales, 'TIP_CAMBIO', v_tip_cotizacion, G_VARCHAR);
                    PAW_UTI.pr_add_value(v_datAdicionales, 'COTIZACION', v_cotizacion, G_VARCHAR);
                 END IF;
              END IF;

              IF op.mto_cargo IS NOT NULL THEN
                 PAW_UTI.pr_add_value(v_datAdicionales, 'MTO_CARGO', op.mto_cargo, G_VARCHAR);
              END IF;

              v_detalle.datosCantidad := v_datAdicionales.Count;
              v_detalle.datosAdicionales := v_datAdicionales;
              v_detalle.datosCantidad := v_datAdicionales.count;



              v_lis_detalle(v_lis_detalle.count) := v_detalle;
              v_datAdicionales := typ_listaClaveValor();

           END LOOP;
           v_retorno.cantidadDetalles := v_lis_detalle.count;
           v_retorno.listaDetalles      := v_lis_detalle;
           RETURN v_retorno;
        END;

      FUNCTION fu_rechazarOperaciones(
                                p_cod_persona IN VARCHAR2,
                                p_cod_empresa IN VARCHAR2,
                                p_cod_canal   IN VARCHAR2,
                                p_operaciones IN VARCHAR2,
                                p_id_sesion IN VARCHAR2 DEFAULT NULL)
            RETURN TYP_RECHAZOOPERACION IS
            mp                                 bw_mov_pendientes%ROWTYPE;
            v_lugar                            VARCHAR2(4000);
            v_listaDetalle                     TYP_LISTARECHAZOOPERACION := TYP_LISTARECHAZOOPERACION();
            v_detalle                          TYP_DETALLERECHAZOOPERACION := TYP_DETALLERECHAZOOPERACION();
            v_retorno                          TYP_RECHAZOOPERACION := TYP_RECHAZOOPERACION();
            v_cod_operacion                    VARCHAR2(3) := '023';
            v_cod_perfil                       VARCHAR2(50);
            v_permiso                          typ_permisos;
            v_msj_bitacora      VARCHAR2(800) := substr('operaciones:'||p_operaciones, 1, 800);


            --errores
            PRO_AUT_SIN_PERMISO         CONSTANT VARCHAR2(15) := 'PRO_AUT_SIN_PER';
            PRO_AUT_DOC_INEXISTENTE     CONSTANT VARCHAR2(15) := 'PRO_AUT_DOC_INE';
            PRO_AUT_ERR_OBT_PENDIENTE   CONSTANT VARCHAR2(15) := 'PRO_AUT_ERR_PEN';
            PRO_AUT_ERR_SNP_CANCELA     CONSTANT VARCHAR2(15) := 'PRO_AUT_SNP_CAN';
            PRO_AUT_PED_DUPLICADO       CONSTANT VARCHAR2(15) := 'PRO_AUT_DUPLICA';
         BEGIN
           paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ENTRADA);

           v_cod_perfil := fuw_obt_per_empresa(p_cod_empresa, p_cod_persona);

           v_permiso := paw_seg.fu_obt_permisos(p_cod_empresa, v_cod_perfil, p_cod_canal, v_cod_operacion);

           IF (v_permiso.error = 'S') THEN
              v_retorno.nombreRespuesta      := v_permiso.nombreRespuesta;
              v_retorno.descripcionRespuesta := v_permiso.descripcionRespuesta;
              v_retorno.error                := v_permiso.error;
              paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);

              RETURN v_retorno;
           END IF;
           IF v_permiso.autoriza = 'N' THEN
              paw_uti.pr_mensajeUsuario(PRO_AUT_SIN_PERMISO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
              paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
              RETURN v_retorno;
           END IF;
           IF pae_cnf.FU_OBT_EST_MODULO(3) IN (1,6) THEN
              paw_uti.pr_mensajeUsuario(MSG_MOD_CIERRE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
              paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
              RETURN v_retorno;
           END IF;

           FOR i IN c_lineas(p_operaciones, ',') LOOP
                 BEGIN
                    SELECT *
                    INTO mp
                    FROM bw_mov_pendientes p
                    WHERE p.nro_documento = i.linea
                    AND p.cod_per_principal = p_cod_empresa
                    AND p.estado = 'P';
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       paw_uti.pr_mensajeusuario(PRO_AUT_DOC_INEXISTENTE, v_detalle.nombreRespuesta, v_detalle.descripcionRespuesta, v_detalle.error);
                    WHEN OTHERS THEN
                       paw_uti.pr_mensajeusuario(PRO_AUT_ERR_OBT_PENDIENTE, v_detalle.nombreRespuesta, v_detalle.descripcionRespuesta, v_detalle.error);
                 END;
                 v_permiso := paw_seg.fu_obt_permisos(p_cod_empresa, v_cod_perfil, p_cod_canal, mp.cod_tip_mensaje);

                 IF (v_permiso.error = 'S') THEN
                    v_retorno.nombreRespuesta      := v_permiso.nombreRespuesta;
                    v_retorno.descripcionRespuesta := v_permiso.descripcionRespuesta;
                    v_retorno.error                := v_permiso.error;
                 END IF;
           IF v_permiso.autoriza = 'N' THEN
              paw_uti.pr_mensajeUsuario(PRO_AUT_SIN_PERMISO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
              paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
              RETURN v_retorno;
           END IF;

                 IF v_permiso.error = 'N' THEN
                    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_detalle.nombreRespuesta, v_detalle.descripcionRespuesta, v_detalle.error);

                    IF mp.cod_tip_mensaje = '036' THEN
                    BEGIN
                       UPDATE ge_snp_transferencias gs
                       SET gs.estado = 'C'
                       WHERE gs.nro_referencia = mp.referencia ;
                    EXCEPTION
                       WHEN OTHERS THEN
                          paw_uti.pr_mensajeusuario(PRO_AUT_ERR_SNP_CANCELA, v_detalle.nombreRespuesta, v_detalle.descripcionRespuesta, v_detalle.error);
                          paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
                    END;
                 ELSIF mp.cod_tip_mensaje = '070' THEN
                    pag_sue.LP_DEL_DATOS_TEMPORA(mp.dato, to_date(mp.dato2, 'DD/MM/YYYY'), v_lugar, mp.referencia);
                 ELSIF mp.cod_tip_mensaje = '075' THEN
                    pag_prv.PR_ELI_PROV_TMP(mp.dato, mp.fec_insercion, mp.referencia);
                    pag_prv.PR_ELI_FAC_TMP(mp.dato, mp.fec_insercion, mp.referencia);
                 ELSIF mp.cod_tip_mensaje = '090' THEN
                    DECLARE
                       v_cant NUMBER;
                    BEGIN
                       v_cant := pag_rec.fu_eli_temporal(mp.dato, mp.referencia, to_date(mp.dato2, 'dd/mm/yyyy'))
                       + pag_rec.fu_eli_errores(mp.dato, mp.referencia, to_date(mp.dato2, 'dd/mm/yyyy'));
                    END;
                 ELSIF mp.cod_tip_mensaje = '130' THEN
                    DELETE FROM ge_pag_sue_emp_tmp t
                    WHERE t.cod_empresa = mp.dato
                       AND t.nro_lote = mp.referencia
                       AND trunc(mp.fec_insercion) = trunc(SYSDATE);
                 END IF;

                 UPDATE bw_mov_pendientes
                    SET estado = 'A'
                  WHERE nro_documento = i.linea
                    AND cod_per_principal = p_cod_empresa;

                 IF v_detalle.error = 'N' THEN
                    BEGIN
                      v_detalle.codOperacion := mp.cod_tip_mensaje;
                      v_detalle.numeroDocumento := mp.nro_documento;
                       -- inserto el movimiento por la anulacion
                       INSERT INTO bw_autorizaciones
                       (cod_persona, nro_documento, fec_hora, accion)
                       VALUES
                       (p_cod_persona, i.linea, SYSDATE, 'R');
                    EXCEPTION
                       WHEN dup_val_on_index THEN
                          paw_uti.pr_mensajeusuario(PRO_AUT_PED_DUPLICADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                          paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_empresa, v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || '] ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);
                    END;
                 END IF;
              END IF;
              v_listaDetalle.Extend;
              v_listaDetalle(v_listaDetalle.count) := v_detalle;
              END LOOP;
              v_retorno.cantidad := v_listaDetalle.Count;
              v_retorno.listaDetalles := v_listaDetalle;
            RETURN v_retorno;
         END;

     FUNCTION fu_reg_softoken(p_cod_persona IN VARCHAR2,
                              p_cod_per_vinculada IN VARCHAR2,
                              p_cod_canal  IN VARCHAR2,
                              p_nro_serial IN VARCHAR2,
                              p_cod_dispositivo IN VARCHAR2,
                              p_cla_encriptacion IN VARCHAR2,
                              p_vec_inicializacion IN VARCHAR2,
                              p_dominio IN VARCHAR2,
                              p_modo IN VARCHAR2,
                              p_id_sesion IN VARCHAR2 DEFAULT NULL,
                              p_es_migracion IN VARCHAR2 DEFAULT 'N') RETURN typ_mensajerespuesta IS
        v_ret_softoken  typ_regsoftokenkey := typ_regsoftokenkey();
        v_retorno       typ_mensajerespuesta := typ_mensajerespuesta();
        v_cod_perfil    VARCHAR2(50);
        v_cod_operacion VARCHAR2(3) := '008';
        v_nro_documento NUMBER(15);
        v_permiso       typ_permisos;
        v_tie_aut_token VARCHAR2(1);
        v_msj_bitacora  VARCHAR2(800) := substr('serial:'||p_nro_serial|| ',dominio:' || p_dominio || ',modo:' || p_modo, 1, 800);
        BEGIN
           paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ENTRADA);

           v_cod_perfil := fuw_obt_per_empresa(p_cod_per_vinculada, p_cod_persona);

           v_permiso := paw_seg.fu_obt_permisos(p_cod_per_vinculada, v_cod_perfil, p_cod_canal, v_cod_operacion);

           IF (v_permiso.error = 'S') THEN
              v_retorno.nombreRespuesta      := v_permiso.nombreRespuesta;
              v_retorno.descripcionRespuesta := v_permiso.descripcionRespuesta;
              v_retorno.error                := v_permiso.error;
              paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
              RETURN v_retorno;
           END IF;

           IF v_retorno.error = 'N' THEN
              IF p_modo NOT IN ('A', 'I', 'L') THEN
                 -- todo: cambiar codigo de retorno
                 paw_uti.pr_mensajeUsuario(PRO_AUT_SIN_PERFIL, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                 paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
              ELSE
                 paw_seg.pr_reg_cla_softoken(p_nro_serial, p_cod_persona, p_cod_dispositivo,
                                       p_cla_encriptacion, p_vec_inicializacion,
                                       'P', v_ret_softoken, p_dominio, p_modo, p_cod_per_vinculada, p_es_migracion);
                 paw_uti.pr_mensajeUsuario(v_ret_softoken.nombreRespuesta, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
              END IF;
           END IF;
           IF p_es_migracion = 'N' THEN
              v_tie_aut_token := paw_otp.fu_tie_aut_token(p_cod_persona, p_cod_per_vinculada);

               IF v_retorno.error = 'N' AND v_tie_aut_token = 'S' THEN
                  IF p_modo IN ('A', 'L') THEN
                     DECLARE
                        v_existe VARCHAR2(1);
                     BEGIN
                        BEGIN
                           SELECT 'S'
                           INTO v_existe
                           FROM bw_mov_pendientes
                           WHERE cod_per_principal = p_cod_per_vinculada
                              AND cod_per_ingreso = p_cod_persona
                              AND estado = ('P')
                              AND cod_tip_mensaje = v_cod_operacion
                              AND trunc(fec_insercion) <= trunc(SYSDATE);
                        EXCEPTION
                           WHEN too_many_rows THEN
                              v_existe := 'S';
                           WHEN OTHERS THEN
                              v_existe := 'N';
                        END;
                        IF v_existe = 'N' THEN
                           -- se inserta como movimiento pendiente de autorizacion
                           SELECT s_nro_documento.NEXTVAL
                           INTO v_nro_documento
                           FROM dual;

                           INSERT INTO BW_MOV_PENDIENTES
                             (NRO_DOCUMENTO,
                             COD_PER_PRINCIPAL,
                             FEC_HORA,
                             COD_TIP_MENSAJE,
                             DESCRIPCION,
                             ESTADO,
                             COD_PER_INGRESO,
                             CAN_AUT_REQUERIDAS,
                             CAN_AUT_FALTANTES, 
                             DATO,
                             ETIQUETA)
                          VALUES
                             (v_nro_documento,
                             p_cod_per_vinculada,
                             SYSDATE,
                             v_cod_operacion,
                             'ACTIVACION TOKEN DIGITAL',
                             'P',
                             p_cod_persona,
                             v_permiso.canAutRequeridas,
                             v_permiso.canAutRequeridas,
                             p_nro_serial,
                             'NRO. SERIAL');
                        END IF;
                     END;
                  ELSIF p_modo = 'I' THEN
                     BEGIN
                        UPDATE BW_MOV_PENDIENTES SET ESTADO = 'A'
                         WHERE cod_per_principal = p_cod_per_vinculada 
                           AND cod_per_ingreso = p_cod_persona
                           AND cod_tip_mensaje = v_cod_operacion
                           AND estado IN ('P');
                     END;  
                  END IF;

               END IF;
           END IF;
           RETURN v_retorno;
        END;

   FUNCTION fu_des_softoken(p_cod_persona IN VARCHAR2,
                            p_cod_per_juridica IN VARCHAR2,
                            p_nro_serial IN VARCHAR2,
                            p_dominio IN VARCHAR2,
                            p_cod_canal IN VARCHAR2,
                            p_id_sesion IN VARCHAR2 DEFAULT NULL) 
                            RETURN typ_mensajerespuesta IS
     v_cod_operacion  VARCHAR2(3) := '008';
     v_retorno        typ_mensajerespuesta := typ_mensajerespuesta();
   BEGIN
       PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_juridica, 
           'Desvinculacion SoftToken: ' || p_nro_serial || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null), 
           PAW_UTI.BITACORA_ENTRADA);

       BEGIN
           IF p_dominio = 'CASHPY' THEN
               UPDATE bw_sof_empresas emp
               SET emp.estado = 'I'
               WHERE emp.sof_ser_id IN 
               (
                 SELECT emp.sof_ser_id
                 FROM bw_sof_seriales ser JOIN bw_sof_empresas emp ON ser.id = emp.sof_ser_id
                 WHERE ser.nro_serial = p_nro_serial
                   AND ser.cod_persona = p_cod_persona
               );
           END IF;
       EXCEPTION
           WHEN OTHERS THEN
               PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               PAW_UTI.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_juridica, 
                   'Desvinculacion SoftToken Invalida:' || p_nro_serial || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, null), 
                   PAW_UTI.BITACORA_ERROR);
       END;

       RETURN v_retorno;
   END;

   PROCEDURE pr_obt_dat_tra_internacional(p_nro_documento         IN BW_MOV_PENDIENTES.NRO_DOCUMENTO%TYPE,
                                          fecha                   IN bw_mov_pendientes.Fec_Hora%TYPE,
                                          cod_per_vinculada       IN BW_MOV_PENDIENTES.COD_PER_PRINCIPAL%TYPE,
                                          p_nom_beneficiario     OUT lc_transferencias.nom_beneficiario%TYPE,
                                          p_dir_beneficiario     OUT lc_transferencias.dir_beneficiario%TYPE,
                                          p_nro_cta_referencia   OUT lc_transferencias.nro_cta_referencia%TYPE,
                                          p_nom_banco            OUT lc_transferencias.nom_banco%TYPE,
                                          p_cod_pais             OUT ba_paises.cod_pais%TYPE,
                                          p_cod_ciudad           OUT ba_ciudades.cod_ciudad%TYPE,
                                          p_cod_bco_corresponsal OUT lc_transferencias.cod_bco_corresponsal%TYPE,
                                          p_nom_bco_corresponsal OUT lc_transferencias.nom_bco_cor_contra%TYPE,
                                          p_swi_bco_corresponsal OUT lc_transferencias.cod_swi_bco_contra%TYPE,
                                          p_pai_bco_corresponsal OUT lc_transferencias.cod_pai_bco_contra%TYPE,
                                          p_ciu_bco_corresponsal OUT lc_transferencias.cod_ciu_bco_contra%TYPE,
                                          p_cod_mon_credito      OUT ba_monedas.cod_moneda%TYPE,
                                          p_nro_contrato         OUT lc_ope_pendientes.nro_diario%TYPE,
                                          p_tip_cargo            OUT VARCHAR2,
                                          p_plazo                OUT NUMBER,
                                          p_tip_motivo           OUT lc_transferencias.tip_motivo%TYPE,
                                          p_tip_fondo            OUT lc_transferencias.tip_fondo%TYPE,
                                          p_tip_financiacion     OUT lc_transferencias.tip_financiacion%TYPE,
                                          p_cod_swift            OUT lc_transferencias.cod_swi_banco%TYPE,
                                          p_ref_beneficiario     OUT lc_transferencias.referencia%TYPE,
                                          p_cod_pai_beneficiario OUT lc_transferencias.cod_pai_beneficiario%TYPE,
                                          p_cod_ciu_beneficiario OUT lc_transferencias.cod_ciu_beneficiario%TYPE,
                                          p_ord_pago             OUT VARCHAR2) IS


      v_observacion          lc_transferencias.observacion%TYPE;
      v_parametros           bw_movimientos.parametros%TYPE;

      v_indice               NUMBER := 1;

      BEGIN
         BEGIN
            SELECT observacion, parametros
              INTO v_observacion, v_parametros
              FROM bw_movimientos
             WHERE nro_documento = p_nro_documento
               AND trunc(fec_hora) = trunc(fecha)
               AND cod_per_principal = cod_per_vinculada
               AND cod_tip_mensaje = 227;

            p_nom_beneficiario := TRIM(substr(v_parametros, v_indice, 120)); v_indice := v_indice + 120;
            p_dir_beneficiario := TRIM(substr(v_parametros, v_indice, 100)); v_indice := v_indice + 100;
            p_nom_banco := TRIM(substr(v_parametros, v_indice, 100)); v_indice := v_indice + 100;
            p_nom_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 100)); v_indice := v_indice + 100;
            p_nro_cta_referencia := TRIM(substr(v_parametros, v_indice, 30)); v_indice := v_indice + 30;
            p_cod_pais := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
            p_cod_ciudad := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
            p_cod_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
            p_pai_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
            p_cod_mon_credito := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
            p_nro_contrato := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 10;
            p_tip_cargo := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
            p_plazo := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
            p_tip_motivo := TRIM(substr(v_parametros, v_indice, 2)); v_indice := v_indice + 5;
            p_tip_fondo := TRIM(substr(v_parametros, v_indice, 2)); v_indice := v_indice + 5;
            p_tip_financiacion := TRIM(substr(v_parametros, v_indice, 2)); v_indice := v_indice + 5;
            p_cod_swift := TRIM(substr(v_parametros, v_indice, 20)); v_indice := v_indice + 20;
            p_cod_pai_beneficiario := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
            p_cod_ciu_beneficiario := TRIM(substr(v_parametros, v_indice, 3)); v_indice := v_indice + 5;
            p_ref_beneficiario := TRIM(substr(v_parametros, v_indice, 300)); v_indice := v_indice + 300;
            p_swi_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 20)); v_indice := v_indice + 20;
            p_ciu_bco_corresponsal := TRIM(substr(v_parametros, v_indice, 3));  v_indice := v_indice + 3;
            p_ord_pago := TRIM(substr(v_parametros, v_indice, 20));

            SELECT decode(p_nro_contrato, 0, NULL, p_nro_contrato),
               decode(p_cod_bco_corresponsal, 0, NULL, p_cod_bco_corresponsal),
               decode(p_cod_pai_beneficiario, 0, NULL, p_cod_pai_beneficiario),
               decode(p_cod_ciu_beneficiario, 0, NULL, p_cod_ciu_beneficiario),
               decode(p_pai_bco_corresponsal, 0, NULL, p_pai_bco_corresponsal),
               decode(p_ciu_bco_corresponsal, 0, NULL, p_ciu_bco_corresponsal)
            INTO p_nro_contrato, p_cod_bco_corresponsal, p_cod_pai_beneficiario,
               p_cod_ciu_beneficiario, p_pai_bco_corresponsal, p_ciu_bco_corresponsal
            FROM DUAL;
            
            -- se carga en un segundo query, algunos swifts vienen duplicado y el sgte query puede fallar
            -- TODO: mejorar la busqueda por ciudad y pais
            SELECT decode(p_nom_banco, NULL, fug_obt_des_bco_swift(p_cod_swift), p_nom_banco)
              INTO p_nom_banco
              FROM DUAL;
         EXCEPTION
            WHEN OTHERS THEN
               -- TODO: ver que exception retornar
               RETURN;
         END;
      END;
   --
   FUNCTION fu_not_encolados RETURN NUMBER IS
      v_ret           NUMBER := -1;
      v_tot_encolados NUMBER;
      v_intervalo     ge_par_dinamicos.val_parametro%TYPE := trim(nvl(fug_obt_pardinamico('MAX_INT_PEN_ENCOLADOS'), 10));
      v_lis_correos   ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('DIR_MAI_PEN_ENCOLADOS'));
   BEGIN
      -- busca si hay registros encolados con mas de v_intervalo(default 10) minutos
      SELECT COUNT(0)
        INTO v_tot_encolados
        FROM bw_mov_pendientes p
       WHERE p.estado = 'E'
         AND ((SYSDATE) - p.fec_insercion) * 1440 > v_intervalo;

      IF v_tot_encolados > 0 AND v_lis_correos IS NOT NULL THEN
         v_ret := paw_not.fu_env_email_prueba(v_lis_correos, 'Hay ' || to_char(v_tot_encolados) || ' movimientos pendientes encolados para chequear', 'PAW_BEE');
      END IF;

      RETURN v_ret;
   END;
   
   PROCEDURE pr_act_fec_mov_pend IS    
      v_can_ope_cambio NUMBER;
      v_fec_pago       ge_pag_proveedores_tmp.fec_pago%TYPE;
      v_nro_archivo    ge_pag_proveedores_tmp.nro_archivo%TYPE;
      v_max_dias       NUMBER := nvl(fug_obt_pardinamico('PAG_PRV_MOV_PEND_PLAZO'), 5);
      v_fec_actual     ge_calendarios.fec_actual%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(9);
      --obtener movimientos pendientes dentro del plazo determinado en dias
      CURSOR pendientes IS      
        SELECT * 
          FROM bw_mov_pendientes
         WHERE cod_tip_mensaje = '075'
           AND estado = 'P'
           AND to_date(dato2, 'dd/mm/yyyy') <= v_fec_actual
           AND fuh_obt_dif_dias(trunc(fec_insercion), trunc(v_fec_actual)) <= v_max_dias;

   BEGIN
      FOR reg IN pendientes LOOP
         v_can_ope_cambio := pag_prv.FU_OBT_CAN_OPE_CAMBIO(reg.dato, reg.fec_hora, reg.cod_moneda, reg.referencia);
         IF(v_can_ope_cambio <= 0) THEN
            --actualizar fecha de pago en bw_mov_pendientes y ge_pag_proveedores_tmp 
            v_fec_pago := trunc(to_date(reg.dato2, 'dd/mm/yyyy'));
            v_nro_archivo := reg.referencia;
            lp_cam_fec_pag_proveedores(reg, v_fec_pago, v_nro_archivo);
         END IF;
      END LOOP; 
   END;
   --
   PROCEDURE pr_pen_reintentar(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE,
                               p_retorno       OUT VARCHAR2) IS
      v_cod_canal       cj_cajas.nro_caja%TYPE := '990';
      v_cod_empresa     bw_mov_pendientes.cod_per_principal%TYPE;
      v_cod_persona     bw_mov_pendientes.cod_per_ingreso%TYPE;
      v_cod_tip_mensaje bw_mov_pendientes.cod_tip_mensaje%TYPE;
      v_url             ge_par_dinamicos.val_parametro%TYPE := TRIM(fug_obt_pardinamico('EVE_URL_RUNES'));
      v_api_key         ge_par_dinamicos.val_parametro%TYPE := TRIM(fug_obt_pardinamico('EVE_API_RUNES'));
      v_mensaje VARCHAR2(100);
      v_headers         typ_listaEtiquetaValor := typ_listaEtiquetaValor();
      v_contenido       VARCHAR2(5000);
      v_retorno         typ_postRespuesta;
   BEGIN
      -- validando url
      IF v_url IS NULL THEN
         raise_application_error(-20000, 'Falta definir la url, pardinamico [EVE_URL_RUNES]');
      END IF;
      -- validando apiKey
      IF v_api_key IS NULL THEN
         raise_application_error(-20000, 'Falta definir el apikey, pardinamico [EVE_API_RUNES]');
      END IF;
      -- obtenemos el pendiente encolado
      v_mensaje := 'Buscando enconlado pendiente ' || p_nro_documento;
      SELECT p.cod_per_principal, p.cod_tip_mensaje
        INTO v_cod_empresa, v_cod_tip_mensaje
        FROM bw_mov_pendientes p
       WHERE p.nro_documento = p_nro_documento
         AND p.estado = 'E';
      -- actualizamos el topico
      v_url := replace(v_url, '{topic}', fue_obt_des_refcodes('EVE_RUNES', v_cod_tip_mensaje));
      -- obtenemos el ultimo autorizador
      v_mensaje := 'Buscando ultimo autorizador para ' || p_nro_documento;
      SELECT a.cod_persona
        INTO v_cod_persona
        FROM (SELECT cod_persona
                FROM bw_autorizaciones
               WHERE nro_documento = p_nro_documento
                 AND accion = 'A'
               ORDER BY fec_insercion DESC
             ) a
       WHERE rownum = 1;
      v_mensaje := 'setando el body';
      -- creamos el body
      v_contenido := '{ "codPersona": "'||v_cod_persona||'",'||
	                   ' "codEmpresa": "'||v_cod_empresa||'",'||
	                   ' "codCanal": "'||v_cod_canal||'",'||
	                   ' "documentNumber": "'||p_nro_documento||'",'||
	                   ' "operationType": "'||v_cod_tip_mensaje||'" }';

      -- agregamos los headers para enviar el post
      v_mensaje := 'seteando los headers';
      paw_uti.pr_add_value(v_headers, 'Content-Type', 'application/json');
      paw_uti.pr_add_value(v_headers, 'Runes-Api-Key', v_api_key);
      paw_uti.pr_add_value(v_headers, 'Content-Length', length(v_contenido));
      v_retorno := fue_env_http(v_url, 'POST', v_headers, v_contenido);
      p_retorno := 'Error: '||v_retorno.error||', sCode: '||v_retorno.status_code||', res: '||v_retorno.respuesta;
   EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, v_mensaje || ' ' ||SQLERRM);
   END;

   FUNCTION fu_asi_sof_token(p_session    IN VARCHAR2,
                             p_codCanal   IN NUMBER,
                             p_modo       IN VARCHAR2,
                             p_accion     IN VARCHAR2,
                             p_nro_serial IN VARCHAR2) RETURN typ_mensajerespuesta IS
      v_retorno       typ_mensajerespuesta := typ_mensajerespuesta();
      v_usu_sesion    paw_bel.typ_validarSesion;
      v_permiso       typ_permisos;
      v_cod_operacion bw_tip_mensajes.cod_tip_mensaje%TYPE := '008';
      v_resultado     NUMBER;
      v_msj_bitacora  VARCHAR2(500);
   BEGIN
      v_msj_bitacora := 'modo: '||substr(p_modo, 1, 1)||', acc:'||substr(p_accion, 1, 1)||', serial: '||paw_uti.depurarTextos(p_nro_serial, 50);
      v_usu_sesion := paw_bel.fu_validarSesion(p_session, p_codCanal);
      IF v_usu_sesion.error = 'S' THEN
         v_retorno.error                := v_usu_sesion.error;
         v_retorno.nombreRespuesta      := v_usu_sesion.nombreRespuesta;
         v_retorno.descripcionRespuesta := v_usu_sesion.descripcionRespuesta;
         RETURN v_retorno;
      END IF;
      v_permiso := paw_seg.fu_obt_permisos(v_usu_sesion.codigoEmpresa, v_usu_sesion.codigoPerfil, p_codCanal, v_cod_operacion);
      IF (v_permiso.error = 'S') THEN
         v_retorno.nombreRespuesta      := v_permiso.nombreRespuesta;
         v_retorno.descripcionRespuesta := v_permiso.descripcionRespuesta;
         v_retorno.error                := v_permiso.error;
         paw_uti.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codCanal, p_session, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ERROR);
         RETURN v_retorno;
      END IF;
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      paw_uti.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codCanal, p_session, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ENTRADA);

      v_resultado := paw_otp.fu_sof_tok_admin(p_nro_serial, v_usu_sesion.codigoPersona, v_usu_sesion.codigoEmpresa, p_modo, p_accion);
      v_msj_bitacora := v_msj_bitacora || ', ret: ' || v_resultado;
      IF v_resultado <> 1 THEN
         paw_uti.pr_mensajeUsuario('P_OP_NO_PERM', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codCanal, p_session, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);
      ELSE
        paw_uti.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codCanal, p_session, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_SALIDA);
      END IF;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codCanal, p_session, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ', ERR [' || SQLERRM || ']' ||paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);
         RETURN v_retorno;
   END;
   
   FUNCTION fu_tra_snp(p_cod_persona           IN VARCHAR2,
                       p_cod_empresa           IN VARCHAR2,
                       p_cod_canal             IN VARCHAR2,
                       p_id_sesion             IN VARCHAR2,
                       p_modo                  IN VARCHAR2,
                       p_nroCuentaDebito       IN VARCHAR2, 
                       p_nroCuentaCredito      IN VARCHAR2, 
                       p_codMonCredito         IN VARCHAR2,
                       p_montoCredito          IN NUMBER,
                       p_concepto              IN VARCHAR2, 
                       p_codigoSwift           IN VARCHAR2, 
                       p_nombreBeneficiario    IN VARCHAR2,
                       p_codTipoDocumentoBen   IN NUMBER,
                       p_numeroDocBeneficiario IN VARCHAR2,
                       p_tip_cargos            IN VARCHAR2,
                       p_canFirmas             IN NUMBER,
                       p_numeroContrato        IN NUMBER DEFAULT NULL) RETURN TYP_MAPA IS
     v_msj_caja         typ_mensajeCaja;
     v_retorno          typ_mapa := typ_mapa();
     v_tra_lote         typ_transferencialote;
     v_abr_tip_documento ba_tip_documentos.abreviatura%TYPE;
     v_lis_etiqueta      typ_listaClaveValor := typ_listaClaveValor();
   BEGIN
      -- obtenemos datos del nro. de caja
      v_msj_caja   := paw_seg.fu_val_caja(p_cod_canal);
      -- invocamos a la transaccion
      v_tra_lote   := paw_bas.fu_TransferenciaInterbancaria(
                                         v_msj_caja,
                                         p_cod_canal, 
                                         p_modo,
                                         p_cod_persona,
                                         p_cod_empresa, 
                                         NULL, -- fecha valor
                                         p_nroCuentaDebito, 
                                         p_nroCuentaCredito, 
                                         p_codMonCredito,
                                         p_montoCredito,
                                         p_concepto,
                                         p_codigoSwift, 
                                         p_nombreBeneficiario,
                                         NULL, -- direccion beneficiario
                                         p_codTipoDocumentoBen,
                                         p_numeroDocBeneficiario, 
                                         p_id_sesion,
                                         NULL, -- prioridad 
                                         nvl(p_tip_cargos, 'O'),
                                         p_canFirmas,
                                         p_numeroContrato);
      -- cargamos los datos de salida
      v_retorno.error := v_tra_lote.error;
      v_retorno.nombreRespuesta := v_tra_lote.nombreRespuesta;
      v_retorno.descripcionRespuesta := v_tra_lote.descripcionRespuesta;
      BEGIN
        SELECT d.abreviatura
          INTO v_abr_tip_documento 
          FROM ba_tip_documentos d
         WHERE d.cod_tip_documento = p_codTipoDocumentoBen;
         paw_uti.pr_add_value(v_lis_etiqueta, 'DES_TIP_DOC_BENEFICIARIO', v_abr_tip_documento, G_VARCHAR);
      EXCEPTION
        WHEN OTHERS THEN
           NULL;
      END;
      
      paw_uti.pr_add_value(v_lis_etiqueta, 'NRO_CTA_DEBITO', v_tra_lote.NumeroCuenta, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'COD_MON_DEBITO', v_tra_lote.CodigoMoneda, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'MTO_DEBITO', v_tra_lote.Monto, G_NUMBER);
      paw_uti.pr_add_value(v_lis_etiqueta, 'COT_DEBITO', v_tra_lote.cotizacionDebito, G_NUMBER);
      paw_uti.pr_add_value(v_lis_etiqueta, 'NRO_CTA_CREDITO', v_tra_lote.NroCuentaCredito, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'COD_MON_CREDITO', v_tra_lote.CodigoMonedaCredito, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'MTO_CREDITO', v_tra_lote.MontoCredito, G_NUMBER);
      paw_uti.pr_add_value(v_lis_etiqueta, 'COT_CREDITO', v_tra_lote.cotizacionCredito, G_NUMBER);
      paw_uti.pr_add_value(v_lis_etiqueta, 'TIP_DOC_BENEFICIARIO', v_tra_lote.CodigoDocBeneficiario, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'NRO_DOC_BENEFICIARIO', v_tra_lote.NumeroDocBeneficiario, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'NOM_BENEFICIARIO', v_tra_lote.NombreBeneficiario, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'FEC_PAGO', to_char(v_tra_lote.FechaPago, 'yyyy-mm-dd'), G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'HOR_PAGO', to_char(sysdate, 'hh24:mi:ss'), G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'COD_SWI_BANCO', v_tra_lote.CodigoBanco, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'CONCEPTO', v_tra_lote.Concepto, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'NRO_REFERENCIA', v_tra_lote.NroReferencia, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'NRO_OPERACION', v_tra_lote.nroDocumento, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'NOM_CTA_DEBITO', v_tra_lote.nombreCuentaDebito, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'NOM_BCO_DESTINO', v_tra_lote.nombreBcoDestino, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'PRIORIDAD', v_tra_lote.prioridad, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'TIP_CARGOS', v_tra_lote.tipoCargo, G_VARCHAR);
      paw_uti.pr_add_value(v_lis_etiqueta, 'NRO_CON_CAMBIO', p_numeroContrato, G_NUMBER);
      
      v_retorno.cantidad := v_lis_etiqueta.count;
      v_retorno.datosAdicionales := v_lis_etiqueta;
      RETURN v_retorno;
   END;
    
BEGIN
   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9;
END PAW_BEE;
/

