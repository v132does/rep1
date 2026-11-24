CREATE OR REPLACE PACKAGE BODY IT.PAG_SER IS
  -- Variables para control de errores
 g_fre_proceso VARCHAR2(1) := fug_obt_fre_proceso('PAG_SER.PR_PRO_DEB_AUTOMATICO');
 g_db_prod     VARCHAR2(1) := fug_ind_produccion;
PROCEDURE pr_ver_servicio( p_cod_servicio IN GE_COB_SERVICIOS.COD_SERVICIO%TYPE,
                          p_cta_debito   IN GE_COB_SERVICIOS.NRO_CTA_DEBITO%TYPE,
                          p_referencia1  IN GE_COB_SERVICIOS.REFERENCIA1%TYPE,
                          p_referencia2  IN GE_COB_SERVICIOS.REFERENCIA2%TYPE,
                          p_par_referencia1 out ge_cob_servicios.referencia1%type) IS
 /* || Verifica los datos del servicio a procesar.
 || Controla que las referencias ingresadas tengan el formato
 || adecuado para ser procesado y que cumpla con las reglas definidas
 || por el usuario en la tabla GE_COB_SER_PARAMETROS. Tambien verifica
 || que las monedas de la cuenta del servicio y la cuenta de debito del
 || cliente sean iguales.
 || * PPalella ==> 02/08/2005 */
 v_for_campo1   GE_COB_SER_PARAMETROS.FOR_CAMPO1%TYPE;
 v_val_campo1   GE_COB_SER_PARAMETROS.VAL_CAMPO1%TYPE;
 v_for_campo2   GE_COB_SER_PARAMETROS.FOR_CAMPO2%TYPE;
 v_val_campo2   GE_COB_SER_PARAMETROS.VAL_CAMPO2%TYPE;
 v_cta_servicio GE_COB_SER_PARAMETROS.NRO_CUENTA%TYPE;
 v_mon_servicio BA_MONEDAS.COD_MONEDA%TYPE;
 v_mon_cuenta   BA_MONEDAS.COD_MONEDA%TYPE;
 v_error        EXCEPTION;
 v_fec_vto_cuenta ge_cob_ser_cuentas.fec_vencimiento%type;
 v_referencia     ge_cob_ser_cuentas.referencia%type;
BEGIN
   -- Busca los datos del servicio
   BEGIN
      select for_campo1, val_campo1, for_campo2, val_campo2, nro_cuenta
        into v_for_campo1, v_val_campo1, v_for_campo2, v_val_campo2, v_cta_servicio
        from ge_cob_ser_parametros
       where cod_servicio = p_cod_servicio;
   EXCEPTION
      when others then
        pag_ser.g_cod_error := -20601;
        pag_ser.g_men_error := 'No se pudieron obtener los datos del servicio ' || sqlerrm;
        raise v_error;
   END;
   BEGIN
      select cod_moneda
        into v_mon_servicio
        from ge_cuentas
       where nro_cuenta = v_cta_servicio;
   EXCEPTION
      when v_error then
        raise v_error;
      when others then
        pag_ser.g_cod_error := -20602;
        pag_ser.g_men_error := 'No encontro la cuenta del servicio ' || sqlerrm;
        raise v_error;
   END;
   --verificar datos de la cuenta
   pag_cta.PR_OBT_CUENTA(p_cta_debito);
   If pag_cta.fu_obt_cod_error() <> 0 THEN
     pag_ser.g_cod_error := -20679;
     pag_ser.g_men_error := 'Cta '||p_cta_debito||'-'||pag_cta.FU_OBT_MSJ_ERROR;
     raise v_error;
   end if;
   -- verifica que la cuenta tenga autorizacion para el debito, ge_cob_ser_cuentas
   begin
      select t.fec_vencimiento, t.referencia, g.cod_moneda
        into v_fec_vto_cuenta, v_referencia, v_mon_cuenta
        from ge_cob_ser_cuentas t, ge_cuentas g
       where t.cod_servicio = p_cod_servicio
         and nvl(t.autorizado, 'N') = 'S'
         and nvl(t.tipo, 'P') = 'M'
         and pag_cal.fu_obt_fec_actual(1) >= t.fec_inicio
         and t.nro_cuenta = g.nro_cuenta
         and t.nro_cuenta = p_cta_debito
         and t.referencia = nvl(p_referencia1, t.referencia);--puede tener varias fact x del mismo serv x cuenta
      --valida los datos
      if v_fec_vto_cuenta < pag_cal.fu_obt_fec_actual(1) then
        pag_ser.g_cod_error := -20609;
        pag_ser.g_men_error := 'Autorizacion de debito para la Cta '||p_cta_debito||' ha vencido. Verifique la fecha ';
        raise v_error;
      end if;
      if p_referencia1 is not null then--si tiene valida, sino toma de la parametrizacion
         if v_referencia <> p_referencia1 then
           pag_ser.g_cod_error := -20610;
           pag_ser.g_men_error := 'Referencia1 de la cuenta '||p_cta_debito||' no corresponde a la Referencia autorizada. Verifique.';
           raise v_error;
         end if;
      else
         p_par_referencia1 := v_referencia;
      end if;
   exception
      when v_error then
        raise v_error;
      when no_data_found then
        pag_ser.g_cod_error := -20607;
        pag_ser.g_men_error := 'Cuenta '||p_cta_debito||' no autorizada para debito por el servicio. ';
        raise v_error;
      when others then
        pag_ser.g_cod_error := -20608;
        pag_ser.g_men_error := 'Recup.Cta parametrizada para debito por el servicio '||p_cta_debito||'.'|| sqlerrm;
        raise v_error;
   end;
   IF nvl( v_mon_servicio, 'x' ) <> nvl( v_mon_cuenta, 'x' ) THEN
      pag_ser.g_cod_error := -20604;
      pag_ser.g_men_error := 'La moneda del servicio( ' || v_mon_servicio ||
                             ' ) no coincide con la de la cta a debitar ( ' || v_mon_cuenta || ').'||p_cta_debito;
      raise v_error;
   END IF;
   -- Evalua el dato ingresado en REFERENCIA 1
   lp_val_referencia( p_referencia1,
                    v_for_campo1,
                    v_val_campo1 );
   -- Si el proceso devolvio un error, entonces aclara que es por el campo de REFERENCIA 1
   IF pag_ser.g_cod_error <> 0 THEN
      --si es x ascii no es obligatorio el campo referencia1, q siga el proceso
      if pag_ser.g_cod_error = -20786 then
         --cerar var de error
         pag_ser.pr_ini_variables;
      else
         pag_ser.g_cod_error := -20602;
         pag_ser.g_men_error := 'ERROR al validar la referencia 1. ' || chr(13) || pag_ser.g_men_error;
         raise v_error;
      end if;
   END IF;
   -- Verifica que el documento no haya sido ingresado anteriormente
   IF v_val_campo1 = 'U' AND
      lf_ya_fue_grabado( p_cod_servicio, p_referencia1, 1 ) = 'S' THEN
      IF pag_ser.g_cod_error <> 0 THEN
         raise v_error;
      END IF;
      pag_ser.g_cod_error := -20603;
      pag_ser.g_men_error := 'Documento ya fue grabado anteriormente.';
      raise v_error;
   END IF;
   -- Evalua el dato ingresado en REFERENCIA 2
   lp_val_referencia( p_referencia2,
                    v_for_campo2,
                    v_val_campo2 );
   -- Si el proceso devolvio un error, entonces aclara que es por el campo de REFERENCIA 1
   IF pag_ser.g_cod_error <> 0 THEN
      pag_ser.g_cod_error := -20602;
      pag_ser.g_men_error := 'ERROR al validar la referencia 2. ' || chr(13) || pag_ser.g_men_error;
      raise v_error;
   END IF;
   -- Verifica que el documento no haya sido ingresado anteriormente
   IF v_val_campo2 = 'U' AND
      lf_ya_fue_grabado( p_cod_servicio, p_referencia2, 2 ) = 'S' THEN
      IF pag_ser.g_cod_error <> 0 THEN
         raise v_error;
      END IF;
      pag_ser.g_cod_error := -20605;
      pag_ser.g_men_error := 'Documento ya fue grabado anteriormente.';
      raise v_error;
   END IF;
EXCEPTION
 when v_error then
   NULL;
 when others then
   pag_ser.g_cod_error := -20604;
   pag_ser.g_men_error := 'Error al verificar el servicio ' || sqlerrm;
END pr_ver_servicio;

/*Funcion que envia mail de reversion al cliente por pago a la SET o pago de servicios*/
FUNCTION fu_env_mail_pag_servicios(p_cod_ws_servicio IN bw_pag_servicios.cod_ws_servicios%TYPE,
                         p_nro_cuenta      IN ge_cuentas.nro_cuenta%TYPE,
                         p_nro_boleta      IN ge_set_pagos.nro_boleta%TYPE,
                         p_fecha           IN DATE,
                         p_cierre          IN VARCHAR2,
                         p_nro_transaccion IN bw_pag_servicios.nro_transaccion%TYPE ) RETURN NUMBER IS

  PRAGMA AUTONOMOUS_TRANSACTION;
  v_ruc            ge_set_pagos.ruc%TYPE;
  v_monto          ge_set_pagos.monto%TYPE;
  v_fec_documento  ge_set_pagos.fec_documento%TYPE;
  v_nro_operacion  ge_set_pagos.nro_operacion%TYPE;
  v_result         NUMBER := 0;
  v_cierre         varchar2(1);
  v_texto          varchar2(2000);
  v_dir_correo     varchar2(100);
  v_cod_per_debito ba_personas.cod_persona%Type := null;
  v_mto_debito      bw_pag_servicios.mto_debito%TYPE;
  v_cod_servicio    bw_pag_servicios.cod_servicio%TYPE;
  v_cod_proveedor   bw_pag_servicios.cod_proveedor%TYPE;
  v_des_servicio    bw_pag_cod_servicios.descripcion%TYPE;
  v_cabecera   VARCHAR2(700)  := NULL;
  v_detalle    VARCHAR2(3300) := NULL;
  v_pie        VARCHAR2(500)  := NULL;
  v_tag        VARCHAR2(50);
  v_nombre     VARCHAR2(100);
BEGIN
  --obtengo el cliente principal
  v_cod_per_debito := fug_obt_cli_principal(p_nro_cuenta);
  --parametros recibidos
  v_cierre     := p_cierre;
  --obtenemos el nombre del cliente
  v_nombre :=  fue_obt_nom_persona(fug_obt_cli_principal(p_nro_cuenta));
  --obtengo la direccion de correo
  BEGIN
    v_dir_correo := paw_seg.fu_obt_mail(fug_obt_cli_principal(p_nro_cuenta));
  EXCEPTION
    when others then
      v_dir_correo := null;
  END;
  --buscamos datos del pago a la set
  BEGIN
    select s.ruc, s.monto, s.fec_documento, s.nro_operacion
      into v_ruc, v_monto, v_fec_documento, v_nro_operacion
      from ge_set_pagos s
     where s.cod_Token = p_cod_ws_servicio
       and s.nro_cta_debito = p_nro_cuenta
       and s.fec_pago = p_fecha
       and s.nro_boleta = p_nro_boleta;
  EXCEPTION
    WHEN OTHERS THEN
      v_nro_operacion := NULL;
  END;
  --buscamos datos el pago de servicio
   BEGIN
    select a.mto_debito, a.cod_servicio, a.cod_proveedor, b.descripcion
      into v_mto_debito, v_cod_servicio, v_cod_proveedor, v_des_servicio
      from BW_PAG_SERVICIOS a
     INNER JOIN bw_pag_cod_servicios b
            ON a.cod_servicio = b.cod_servicio
            and a.cod_proveedor = b.cod_proveedor
     where a.nro_cuenta = p_nro_cuenta
       and a.cod_ws_servicios = p_cod_ws_servicio
       and a.nro_transaccion = p_nro_transaccion
       and a.fecha = p_fecha;
   EXCEPTION
      WHEN OTHERS THEN
        v_cod_servicio := NULL;
   END;
  if v_cod_proveedor = 2 then
  --verificamos si el mail es por reversion en el inicio de dia
  if v_cierre = 'S' then
      v_texto := 'Estimado Cliente, le informamos que la siguiente operación de pago a la SET realizada desde el Home Banking no pudo <br>ser procesada y será reversada en un plazo máximo de 72 horas.';
  else
      v_texto := 'Estimado Cliente, le informamos que se reversó la siguiente operación de pago a la SET realizada desde el Home Banking, <br>debido a que no pudo ser procesada.';
  end if;
  if v_dir_correo is not null and v_nro_operacion is not null then
     		-- ---------- cabecera --------------
        v_cabecera :=
              -- inicio div
              paw_pro.fu_not_inicio ||
              -- titulo
              paw_pro.fu_not_titulo(UTL_URL.ESCAPE('REVERSIÓN DE PAGO A LA SET', TRUE, 'UTF-8'));
        -- subtitulo
        v_cabecera := v_cabecera ||
        paw_pro.fu_not_sub_titulo(UTL_URL.ESCAPE(v_texto, TRUE, 'UTF-8'));
        v_cabecera := v_cabecera ||
              -- inicio tabla
              paw_pro.fu_not_ini_tabla ||
              -- inicio tbody
              paw_pro.fu_not_ini_tab_cuerpo;
        -- ---------- pie --------------
        -- fin tabla, fin div
        v_pie :=
              -- fin tbody
              paw_pro.fu_not_fin_tab_cuerpo ||
              -- fin table
              paw_pro.fu_not_fin_tabla;
        -- detalles
        v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Nombre del Cliente', TRUE, 'UTF-8'), v_nombre);
        v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Nro. Cuenta Débito', TRUE, 'UTF-8'), p_nro_cuenta);
        v_detalle := v_detalle || paw_pro.fu_not_row_tag('RUC', v_ruc);
		v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nro. Boleta', p_nro_boleta);
        v_detalle := v_detalle || paw_pro.fu_not_row_tag('Monto', to_char((v_monto), '999G999G999G999G999'));
	      v_detalle := v_detalle || paw_pro.fu_not_row_tag('Fecha'||v_tag, to_char(v_fec_documento, 'dd/mm/yyyy'));
        v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nro. Comprobante', v_nro_operacion);
        -- fin div
        v_pie := v_pie || paw_pro.fu_not_fin;

        IF fug_ind_produccion = 'S' THEN --si es produccion
             v_result := paw_not.fu_env_email_prueba(v_dir_correo,
                                             v_cabecera || v_detalle || v_pie,
                                              'PAG_SER');

          IF v_result = 0 then
              insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
              values (fug_obt_dir_correo, v_dir_correo, 'PAG_SER.fu_env_mail_pag_servicios'||'-'||'Mail reversion pago SET', 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cuenta ||' - '||substr(v_detalle,1,3900), sysdate, user)  ;
               commit;
          else
              insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
              values (fug_obt_dir_correo, v_dir_correo, 'PAG_SER.fu_env_mail_pag_servicios'||'-'||'Mail reversion pago SET, no enviado', 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cuenta ||' - '||substr(v_detalle,1,3900), sysdate, user)  ;
               commit;
          end if;
        ELSE -- si no corresponde al entorno de ejecucion de produccion.
               v_result := -90;
               insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
              values (fug_obt_dir_correo, v_dir_correo, 'PAG_SER.fu_env_mail_pag_servicios'||'-'||'Mail reversion pago SET', 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cuenta ||' - Entorno de ejecucion invalido.', sysdate, user)  ;
               commit;
        END IF;
    else  -- si no se encontro correo
       v_result := -91;
       insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
        values (fug_obt_dir_correo, v_dir_correo, 'PAG_SER.fu_env_mail_pag_servicios'||'-'||'Mail reversion pago SET', 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cuenta ||' - No se encontro un correo configurado segun los criterios definidos.', sysdate, user)  ;
        commit;
   END IF;
       return v_result;
  elsif v_cod_proveedor in (0,1,4) then
    --verificamos si el mail es por reversion en el inicio de dia
    if v_cierre = 'S' then
      v_texto := 'Estimado Cliente, le informamos que la siguiente operación de pago de servicio realizada desde el Home Banking no pudo <br>ser procesada y será reversada en un plazo máximo de 72 horas.';
    else
      v_texto := 'Estimado Cliente, le informamos que se reversó la siguiente operación de pago de servicio realizada desde el Home Banking, <br>debido a que no pudo ser procesada.';
    end if;
    if v_dir_correo is not null and v_cod_servicio is not null then
              -- ---------- cabecera --------------
              v_cabecera :=
                    -- inicio div
                    paw_pro.fu_not_inicio ||
                    -- titulo
                    paw_pro.fu_not_titulo(UTL_URL.ESCAPE('REVERSIÓN DE PAGO DE SERVICIO', TRUE, 'UTF-8'));
              -- subtitulo
              v_cabecera := v_cabecera ||
              paw_pro.fu_not_sub_titulo(UTL_URL.ESCAPE(v_texto, TRUE, 'UTF-8'));
              v_cabecera := v_cabecera ||
                    -- inicio tabla
                    paw_pro.fu_not_ini_tabla ||
                    -- inicio tbody
                    paw_pro.fu_not_ini_tab_cuerpo;
              -- ---------- pie --------------
              -- fin tabla, fin div
              v_pie :=
                    -- fin tbody
                    paw_pro.fu_not_fin_tab_cuerpo ||
                    -- fin table
                    paw_pro.fu_not_fin_tabla;
              -- detalles
              v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Nombre del Cliente', TRUE, 'UTF-8'), v_nombre);
              v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Nro. Cuenta Débito', TRUE, 'UTF-8'), p_nro_cuenta);
              v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Servicio', TRUE, 'UTF-8'), v_des_servicio);
              v_detalle := v_detalle || paw_pro.fu_not_row_tag('Monto', to_char((v_mto_debito), '999G999G999G999G999'));
              v_detalle := v_detalle || paw_pro.fu_not_row_tag('Fecha'||v_tag, to_char(p_fecha, 'dd/mm/yyyy'));
              -- fin div
              v_pie := v_pie || paw_pro.fu_not_fin;
        IF fug_ind_produccion = 'S' THEN --si es produccion
            v_result := paw_not.fu_env_email_prueba(v_dir_correo,
                                            v_cabecera || v_detalle || v_pie,
                                              'PAG_SER');
              IF v_result = 0 then
                  insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                  values (fug_obt_dir_correo, v_dir_correo, 'PAG_SER.fu_env_mail_pag_servicios'||'-'||'Mail reversion pago de servicio', 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cuenta ||' - '||substr(v_detalle,1,3900), sysdate, user)  ;
                   commit;
              else
                  insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                  values (fug_obt_dir_correo, v_dir_correo, 'PAG_SER.fu_env_mail_pag_servicios'||'-'||'Mail reversion pago de servicio, no enviado', 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cuenta ||' - '||substr(v_detalle,1,3900), sysdate, user)  ;
                   commit;
              end if;
        ELSE -- si no corresponde al entorno de ejecucion de produccion.
             v_result := -91;
             insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
              values (fug_obt_dir_correo, v_dir_correo, 'PAG_SER.fu_env_mail_pag_servicios'||'-'||'Mail reversion pago de servicio', 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cuenta ||' - Entorno de ejecucion invalido.', sysdate, user)  ;
              commit;
        END IF;
    else  -- si no se encontro correo o codigo de servicio
       v_result := -92;
       insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
        values (fug_obt_dir_correo, v_dir_correo, 'PAG_SER.fu_env_mail_pag_servicios'||'-'||'Mail reversion pago de servicio', 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cuenta ||' - No se encontro un correo configurado segun los criterios definidos.', sysdate, user)  ;
        commit;
   END IF;
       return v_result;
  end if;
  EXCEPTION
     WHEN OTHERS THEN
         v_detalle := substr(sqlerrm, 1,3800);
         insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
         values (fug_obt_dir_correo, v_dir_correo, 'PAG_SER.fu_env_mail_pag_servicios'||'-'||'Mail reversion','Cliente.:'||v_cod_per_debito||'Cliente Déb.:'||p_nro_cuenta||'-'||v_detalle, sysdate, user)  ;
          commit;
        RETURN -99;
  END;

PROCEDURE lp_val_referencia( p_val_ref IN GE_COB_SERVICIOS.REFERENCIA1%TYPE,
                            p_formato IN GE_COB_SER_PARAMETROS.FOR_CAMPO1%TYPE,
                            p_validar IN GE_COB_SER_PARAMETROS.VAL_CAMPO1%TYPE
                            ) IS
 /* || Procedimiento interno que verifica el formato de P_REFERENCIA con
 || los datos de formato recibidos en P_FORMATO, y de acuerdo a P_VALIDAR
 || para mostrar o no una alerta.
 || Los formatos se cargan en la tabla GE_COB_SER_PARAMETROS
 || * PPalella ==> 02/08/2005 */
 v_formato VARCHAR2(1);
 v_letra   VARCHAR2(1);
 verror    EXCEPTION;
 v_abc     VARCHAR2(30) := 'ABDECFGHIJKLMNOPQRSTUVWXYZ';
 v_num     VARCHAR2(10) := '0123456789';
 v_long    NUMBER(3) := LENGTH(p_formato);
 v_fecha   DATE;
 v_ref     VARCHAR2(20);
BEGIN
   IF p_val_ref IS NOT NULL THEN
      v_ref := ltrim( p_val_ref );
      --- verifico el formato y la longitud del campo ---
      IF length( v_ref ) > v_long THEN
        pag_ser.g_cod_error := -20780;
        pag_ser.g_men_error := 'El dato solo puede tener ' || to_char( length( p_formato ) ) || ' caracteres.';
        raise verror;
      END IF;
      IF p_formato = '99/99/9999' THEN  /* formato de fecha */
        BEGIN
          v_fecha := to_date( v_ref, 'DD/MM/YYYY' );
        EXCEPTION
          when others then
            pag_ser.g_cod_error := -20781;
            pag_ser.g_men_error := 'El Dato debe tener el formato ' || p_formato;
            raise verror;
        END;
      END IF;
      IF p_formato <> substr('999999999999999999999', 1, v_long) AND length(v_ref) <> v_long THEN
        pag_ser.g_cod_error := -20782;
        pag_ser.g_men_error := 'El dato debe tener ' || to_char( v_long ) || ' caracteres';
        raise verror;
      END IF;
      FOR II IN 1..v_long LOOP
        v_formato := substr( p_formato, II, 1 );
        v_letra   := substr( v_ref, II, 1 );
        IF v_formato = 'A' THEN
          IF instr( v_abc, v_letra ) = 0 THEN
            pag_ser.g_cod_error := -20783;
            pag_ser.g_men_error := 'El Dato debe tener el formato ' || p_formato;
            raise verror;
          END IF;
        ELSIF v_formato = 'X' THEN
          IF instr( v_abc || v_num, v_letra ) = 0 THEN
            pag_ser.g_cod_error := -20784;
            pag_ser.g_men_error := 'El Dato debe tener el formato ' || p_formato;
            raise verror;
          END IF;
        ELSIF v_formato = '9' THEN
          IF v_letra IS NOT NULL AND
            instr( v_num, v_letra ) = 0 THEN
            raise verror;
          END IF;
        ELSIF v_letra <> v_formato THEN
          pag_ser.g_cod_error := -20785;
          pag_ser.g_men_error := 'El Dato debe tener el formato ' || p_formato;
          raise verror;
        END IF;
      END LOOP;
   ELSE
      -- valor nulo --
      IF p_validar NOT IN( 'S', 'N' ) THEN
        pag_ser.g_cod_error := -20786;
        pag_ser.g_men_error := 'Debe ingresar este dato.';
        raise verror;
      END IF;
   END IF;
EXCEPTION
 when verror then
   NULL;
 when others then
   pag_ser.g_cod_error := -20787;
   pag_ser.g_men_error := 'Al validar formato ' || sqlerrm;
END lp_val_referencia;

FUNCTION lf_ya_fue_grabado( p_cod_servicio IN GE_COB_SERVICIOS.COD_SERVICIO%TYPE,
                            p_referencia   IN GE_COB_SERVICIOS.REFERENCIA1%TYPE,
                            p_tipo         IN NUMBER ) RETURN VARCHAR2 IS
 /* || Verifica que el documento P_REFERENCIA, no haya sido ingresado ya en
 || el dia de hoy para el servicio P_COD_SERVICIO.
 || P_TIPO es para diferenciar la REFERENCIA 1 o 2.
 || * PPalella ==> 02/08/2005 */
 --si fue con error, si se puede repetir, VC
 v_ingresado VARCHAR2(1) := 'N';
BEGIN
   select decode(nvl(count(*), 0), 0, 'N', 'S')
     into v_ingresado
     from ge_cob_servicios
    where cod_servicio  = p_cod_servicio
      and trunc(fecha) = pag_cal.fu_obt_fec_actual(1)
      and estado = 'P'
      and ((p_tipo = 1 and referencia1 = p_referencia) or
           (p_tipo = 2 and referencia2 = p_referencia));
   return v_ingresado;
EXCEPTION
   when others then
      pag_ser.g_cod_error := -20101;
      pag_ser.g_men_error := 'No se pudo verificar si el documento se encuentra duplicado '||sqlerrm;
      return 'N';
END;

PROCEDURE pr_pro_servicio( p_cod_servicio IN GE_COB_SERVICIOS.COD_SERVICIO%TYPE ) IS
 /* || Proceso que lee la tabla GE_COB_SERVICIOS y luego intenta procesar
 || cada registro. Si se producen errores, estos son procesados en
 || cada procedimiento, y el regisro queda marcado como con error en
 || la tabla GE_COB_SERVICIOS.
 || * PPalella ==> 02/08/2005 */
 --se utiliza para los q se levantaron del ASCII. VC
 --ver si solo tomar los de fecha actual
CURSOR servicio IS
   select *
     from ge_cob_servicios
    where cod_servicio = p_cod_servicio
      and fecha = pag_cal.FU_OBT_FEC_ACTUAL(1)
      and nvl( estado, 'I' ) <> 'P'
      and tip_cobro = 'A' --solo para Ascii
      for update of estado, cod_error, comentarios, fecha, hora, cod_moneda, mto_comision, mto_impuesto;
 v_error   EXCEPTION;
 r_cobro   GE_COB_SERVICIOS%ROWTYPE;
 v_estado  VARCHAR2(1);
 -- Temporales para volcar los resultados de las funciones utilizadas
 v_temporal      NUMBER;
 v_val_cargo     GE_MOVIMIENTOS.VAL_TASA%TYPE;
 v_val_impuesto  GE_MOVIMIENTOS.VAL_TASA%TYPE;
 -- Variables para obtener los datos de la cuenta del cliente
 v_oficina        GE_CUENTAS.COD_OFICINA%TYPE;
 v_modulo         GE_CUENTAS.COD_MODULO%TYPE;
 v_modalidad      GE_CUENTAS.COD_MODALIDAD%TYPE;
 v_par_referencia1 ge_cob_servicios.referencia1%type;
BEGIN
   --iniciliza las variables de error
   pag_ser.pr_ini_variables;
   pag_ser.g_hora := to_char( sysdate, 'HH24:MI:SS' );
   pag_ser.pr_obt_servicio( p_cod_servicio );
   IF pag_ser.g_cod_error <> 0 THEN
      raise v_error;
   END IF;
   FOR x IN servicio LOOP
      r_cobro := x;
      BEGIN
        v_estado := x.estado;
        pag_ser.g_cod_error := 0;
        pag_ser.g_men_error := NULL;
        pag_ser.pr_ver_servicio( p_cod_servicio,
                                 x.nro_cta_debito,
                                 x.referencia1,
                                 x.referencia2,
                                 v_par_referencia1);
        --si la referencia del ascii es distinta a la parametrizada, guardar la parametrizada
        if x.referencia1 is null then
          r_cobro.referencia1 := v_par_referencia1;
        else
          r_cobro.referencia1 := x.referencia1;
        end if;
        IF pag_ser.g_cod_error <> 0 THEN
          r_cobro.estado := 'E';
          r_cobro.cod_error := pag_ser.g_cod_error;
          r_cobro.comentarios := pag_ser.g_men_error;
          goto actualiza_cobro;
        END IF;
        -- Para grabar por cada registro procesado y sus movimientos la misma hora
        --pag_ser.g_hora := pag_gen.fu_obt_sig_segundo( pag_ser.g_hora );
        -- DDSI-265 -- 02/2018 : Se cambia para buscar una hora disponible
        pag_ser.g_hora := fug_obt_hor_disponible(pag_ser.g_fecha, pag_ser.g_hora, user, 'N' );
        -- Inicializar los campos
        r_cobro.fecha       := pag_ser.g_fecha;
        r_cobro.hora        := pag_ser.g_hora;
        r_cobro.cod_moneda  := pag_ser.g_cod_moneda;
        -- cero los errores x si es reproceso y estaba con error anteriormente
        pag_ser.pr_ini_variables;
        r_cobro.cod_error   := pag_ser.g_cod_error;
        r_cobro.comentarios := pag_ser.g_men_error;
        -- Procesa el cobro de la cuenta
        pag_ser.pr_pro_debito( r_cobro, 'A' );
        IF pag_ser.g_cod_error <> 0 THEN
          r_cobro.estado := 'E';
          r_cobro.cod_error := pag_ser.g_cod_error;
          r_cobro.comentarios := pag_ser.g_men_error;
        ELSE
          r_cobro.estado := 'P';
        END IF;
        <<actualiza_cobro>> --si da error viene aca para actualizar
        BEGIN
          update ge_cob_servicios
             set estado       = r_cobro.estado,
                 cod_error    = r_cobro.cod_error,
                 comentarios  = r_cobro.comentarios,
                 fecha        = r_cobro.fecha,
                 hora         = r_cobro.hora,
                 cod_moneda   = r_cobro.cod_moneda,
                 referencia1  = r_cobro.referencia1
           where current of servicio;
          IF sql%notfound THEN
            pag_ser.g_cod_error := -20202;
            pag_ser.g_men_error := 'ERROR. Al actualiza ge_cob_servicios ' || sqlerrm;
            raise v_error;
          END IF;
        END;
      END;
   END LOOP;
EXCEPTION
 when v_error then
   NULL;
 when others then
   pag_ser.g_cod_error := -20203;
   pag_ser.g_men_error := 'ERROR. Al procesar las cuentas recibidas ' || sqlerrm;
END;

PROCEDURE pr_ins_cobro( p_reg         IN GE_COB_SERVICIOS%ROWTYPE,
                       p_transaccion IN NUMBER,
                       p_operacion   IN VARCHAR2
                       ) IS
 /* || Proceso que inserta el cobro del servicio.
 || Primero busca sel siguiente numero de operacion que le corresponde
 || de acuerdo al valor de P_OPERACION (tip_cobro) (Los valores validos son (M= Debito Manual,
 || A= Debito por Archivo Ascii, C= Cobro en Caja, E= Bca. Electronica,
 || P= Proceso Periodico). Luego obtiene los cargos y el impuesto, de acuerdo al monto
 ||a cobrar y por ultimo inserta el cobro.
 || * PPalella ==> 02/08/2005 */
 v_nro_operacion GE_COB_SERVICIOS.NRO_OPERACION%TYPE;
BEGIN
 -- Busca los datos que necesita el proceso.
 -- Numero de operacion, oficina, modulo, modalidad, y los cargos que se aplican al monto a cobrar.
 --para el nro de operacion se utiliza el par_dinamico SIG_NRO_SERVICIO
 if p_reg.nro_operacion is not null then
    v_nro_operacion := p_reg.nro_operacion;
 else
    BEGIN
      select nvl( max( nro_operacion ), 0 ) + 1
        into v_nro_operacion
        from ge_cob_servicios
       where cod_servicio = p_reg.cod_servicio
         and tip_cobro = nvl(p_operacion, p_reg.tip_cobro);
    EXCEPTION
      when others then
        v_nro_operacion := 1;
    END;
 end if;
 -- Inserta el registro de cobro
 BEGIN
   insert into ge_cob_servicios( cod_servicio,
                                 tip_cobro,
                                 nro_operacion,
                                 fecha,
                                 hora,
                                 cod_usuario,
                                 cod_ofi_origen,
                                 referencia1,
                                 referencia2,
                                 nro_caja,
                                 monto,
                                 cod_moneda,
                                 mto_efectivo,
                                 mto_che_nue_banco,
                                 mto_che_otr_banco,
                                 mto_debito,
                                 mto_comision,
                                 mto_impuesto,
                                 nro_cta_debito,
                                 estado,
                                 cod_error,
                                 comentarios,
                                 referencia3,
                                 referencia4,
                                 nro_cuota )
                         values( p_reg.cod_servicio,
                                 p_reg.tip_cobro,
                                 v_nro_operacion,
                                 p_reg.fecha,
                                 p_reg.hora,
                                 p_reg.cod_usuario,
                                 p_reg.cod_ofi_origen,
                                 p_reg.referencia1,
                                 p_reg.referencia2,
                                 p_reg.nro_caja,
                                 p_reg.monto,
                                 p_reg.cod_moneda,
                                 p_reg.mto_efectivo,
                                 p_reg.mto_che_nue_banco,
                                 p_reg.mto_che_otr_banco,
                                 p_reg.mto_debito,
                                 p_reg.mto_comision,
                                 p_reg.mto_impuesto,
                                 p_reg.nro_cta_debito,
                                 nvl(p_reg.estado,'I'),
                                 pag_ser.g_cod_error,
                                 substr(pag_ser.g_men_error,1,2000),
                                 p_reg.referencia3,
                                 p_reg.referencia4,
                                 p_reg.nro_cuota );

 EXCEPTION
   when others then
     IF sqlcode <= -20000 THEN
       RAISE;
     ELSE
       pag_ser.g_cod_error := -20307;
       pag_ser.g_men_error := 'No se pudo insertar el cobro ' ||to_char(p_reg.fecha,'dd/mm/yyyy')||'-'||trim(p_reg.referencia1)||'.'|| sqlerrm;
     END IF;
 END;
EXCEPTION
 when others then
   IF sqlcode <= -20000 THEN
     RAISE;
   ELSE
     RAISE_APPLICATION_ERROR( -20308, 'ERROR. En el proceso de insercion de cobro (PR_INS_COBRO) ' || sqlerrm );
   END IF;
END pr_ins_cobro;

PROCEDURE PR_INS_GE_COB_SER_PRIVADOS
 (P_COD_EMPRESA IN NUMBER
 ,P_FECHA IN DATE
 ,P_ERROR OUT VARCHAR2
 )
 IS
 v_nro_operacion number;
/* Inserta en la tabla GE_COB_SER_PRIVADOS */
begin
    BEGIN
      select nvl( max( nro_operacion ), 0 ) + 1
        into v_nro_operacion
        from ge_cob_ser_privados
       where cod_servicio = p_cod_empresa;
    EXCEPTION
      when others then
        v_nro_operacion := 1;
    END;

   insert into ge_cob_ser_privados (
               COD_USUARIO,
               COD_SERVICIO,
               NRO_OPERACION,
               FEC_PROCESO,
               COD_MODALIDAD,
               NRO_CUENTA,
               COD_MONEDA,
               FEC_ENVIO,
               TIPO,
               MONTO,
               ESTADO,
               COD_PROCESO,
               COD_MODULO
         )
           select
               COD_USUARIO,
               COD_SERVICIO,
               V_NRO_OPERACION,
               FEC_PROCESO,
               COD_MODALIDAD,
               NRO_CUENTA,
               COD_MONEDA,
               FEC_ENVIO,
               TIPO,
               MONTO,
               ESTADO,
               COD_PROCESO,
               COD_MODULO
             from ge_cob_ser_privados_tmp
            where cod_Servicio = p_cod_empresa
              and trunc(fec_insercion) = trunc(sysdate)
              and usu_insercion = user;
--              and nvl(tipo,'C') = 'C';

         if sql%notfound then
            p_error := '-20099, Insertar en ge_cob_ser_privados. No existen datos en el tmp';
         else
            p_error := null;
         end if;
exception
   when others then
      p_error := '-20199, Error al insertar Ge_cob_ser_privados.';
end PR_INS_GE_COB_SER_PRIVADOS;

PROCEDURE pr_pro_debito( p_reg  IN GE_COB_SERVICIOS%ROWTYPE,
                         p_tipo IN VARCHAR2 DEFAULT 'I' ) IS
 /* || Proceso que debita el cobro del servicio a la cuenta del cliente y acredita
 || el importe a la cuenta del proveedor del servicio.
 || El proceso recibe toda la informacion necesaria para insertar en GE_COB_SERVICIOS
 || mediante el parametro P_REG
 || * PPalella ==> 02/08/2005 */
/* ||Solo inserta en ge_cob_servicios si viene desde el proceso de deb. automatico, sino
 ||solamente actualiza los saldos de cuentas y genera movimientos (ya q al levantar el
 ||Ascii ya se inserta en la tabla) VC */

 -- Registro local
 v_reg_loc         GE_COB_SERVICIOS%ROWTYPE;
 v_error           EXCEPTION;
 -- Datos de la cuenta del cliente
 v_cli_modulo      GE_CUENTAS.COD_MODULO%TYPE;
 v_cli_modalidad   GE_CUENTAS.COD_MODALIDAD%TYPE;
 --v_cli_oficina     GE_CUENTAS.COD_OFICINA%TYPE;
 -- Datos del usuario
 v_usr_oficina     GE_CUENTAS.COD_OFICINA%TYPE;
 -- Temporales para volcar los resultados de las funciones utilizadas
 v_nvo_estado     AH_CTA_VISTAS.ESTADO%TYPE;
 v_sal_disponible NUMBER(18,2);
 --v_cotizacion     GE_COTIZACIONES.VAL_CONVERSION%TYPE;
 v_procesa        VARCHAR2(1);
 v_secuencia      NUMBER := 0;
 --v_nro_operacion number;
 v_cod_tra_comision ge_transacciones.cod_transaccion%type;
 v_cod_tra_impuesto ge_transacciones.cod_transaccion%type;
 v_com_incluida     varchar2(1);
 v_cod_tas_cargo    ge_movimientos.cod_tasa%type;
 v_val_tas_cargo    ge_movimientos.val_tasa%type;
 v_val_cargo        number;
 v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
 v_val_tas_impuesto ge_movimientos.val_tasa%type;
 v_val_impuesto     number;
 ---
 v_val_exo_cargo    ge_movimientos.val_tasa%type;
 v_val_exo_impuesto ge_movimientos.val_tasa%type;
 v_tip_valor        ge_tasas.tip_valor%type;
 v_redondeo         NUMBER;

BEGIN
   v_reg_loc := p_reg;
   -- Obtiene los datos de la cuenta del servicio
   pag_ser.pr_obt_servicio( v_reg_loc.cod_servicio );
   BEGIN
      select cod_oficina
        into v_usr_oficina
        from ba_usuarios
       where cod_usuario = USER;
   EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_usr_oficina := NULL;
   END;
   v_reg_loc.cod_ofi_origen := v_usr_oficina;
   --RI : 20/01/2010 : Obtener transaccion de comision
   Begin
     Select cod_Tra_comision, com_incluida
       into v_cod_tra_comision, v_com_incluida
       from ge_cob_ser_parametros
      where cod_servicio = v_reg_loc.cod_servicio;
   End;

   -- Verifica que la cuenta del cliente tenga saldo suficiente
   -- para realizar la transaccion.
   pag_cta.pr_ver_operacion( v_reg_loc.nro_cta_debito,
                           pag_ser.g_cod_transaccion,
                           pag_ser.g_cod_modulo,
                           pag_ser.g_cod_modalidad,
                           'D',
                           v_reg_loc.cod_moneda,
                           v_reg_loc.monto,
                           v_reg_loc.cod_ofi_origen,
                           v_cli_modulo,
                           v_cli_modalidad,
                           v_nvo_estado,
                           v_sal_disponible,
                           v_procesa,
                           503 );--transaccion
   -- Si se produjo un error, inserta el debito con errores.
   If (pag_cta.fu_obt_cod_error() <> 0 or v_procesa = 'N')
   and (pag_cta.g_cod_error not in(25, 31, 29)
    or  (pag_cta.g_cod_error in(25, 31, 29) and v_cli_modalidad in(31,41))) then
      v_reg_loc.estado    := 'E';
      pag_ser.g_cod_error := pag_cta.g_cod_error;
      pag_ser.g_men_error := fug_obt_err_sueldos( pag_cta.g_cod_error, 'D' );
      IF nvl( p_tipo, 'I' ) = 'I' THEN --I es de deb auto
         -- Grabar movimiento con error
         pr_ins_cobro( v_reg_loc, pag_ser.g_cod_transaccion, 'P' );
      END IF;
      -- Finalizar la operacion
      raise v_error;
   End if;
   --obtiene el nro de operacion para insertar en los movimientos
   if v_reg_loc.nro_operacion is null then
      BEGIN
         select nvl( max( nro_operacion ), 0 ) + 1
           into v_reg_loc.nro_operacion
           from ge_cob_servicios
          where cod_servicio = p_reg.cod_servicio
            and tip_cobro = nvl(p_reg.tip_cobro,'P');
       EXCEPTION
         when others then
           v_reg_loc.nro_operacion := 1;
       END;
   end if;
   /*************************************** D E B I T O ***************************************/
   -- Intenta DEBITAR los cargos en la cuenta del cliente.
   -- Primero asigna el siguiente numero a la secuencia.
   v_secuencia := nvl( v_secuencia, 0 ) + 1;
   pag_cta.pr_act_operacion( v_reg_loc.nro_cta_debito,        --P_NRO_CUENTA
                           pag_ser.g_hora,                  --P_HORA
                           'D',                             --P_TIP_MOVIMIENTO
                           v_reg_loc.cod_moneda,            --P_COD_MONEDA
                           v_reg_loc.monto,                 --P_MONTO
                           pag_ser.g_cod_transaccion,       --P_COD_TRA_PADRE
                           503,                             --P_COD_TRANSACCION
                           v_reg_loc.nro_operacion,                 --P_NRO_DOCUMENTO
                           null,                            --P_COTIZACION
                           v_reg_loc.cod_ofi_origen,        --P_COD_OFI_ORIGEN
                           pag_ser.g_cod_modulo,            --P_COD_MOD_PADRE
                           pag_ser.g_cod_modalidad,         --P_COD_MAD_PADRE
                           NULL,                            --P_COD_TASA
                           NULL,                            --P_VAL_TASA
                           'Debito Automatico de Cuentas',  --P_CONCEPTO
                           'S',                             --P_EMI_AVISO
                           v_secuencia,                     --P_NRO_SECUENCIA
                           pag_ser.g_fecha,                 --P_FEC_VALOR
                           NULL,
                           NULL );
   -- Si se produjo un error, inserta el debito con errores.
   IF pag_cta.g_cod_error <> 0
   and (pag_cta.g_cod_error not in(25, 31, 29)
    or  (pag_cta.g_cod_error in(25, 31, 29) and v_cli_modalidad in (31,41))) then
      v_reg_loc.estado    := 'E';
      pag_ser.g_cod_error := pag_cta.g_cod_error;
      pag_ser.g_men_error := fug_obt_err_sueldos( pag_cta.g_cod_error, 'D' );
      IF nvl( p_tipo, 'I' ) = 'I' THEN--I es de deb auto
        -- Grabar movimiento con error
        pr_ins_cobro( v_reg_loc, pag_ser.g_cod_transaccion, 'P' );
      END IF;
      -- Finalizar la operacion
      raise v_error;
   END IF;
   ------------------------------------------------------------------------
   /* RI : 20/01/2010 : Intenta DEBITAR la comision si esta no esta
     incluida en el monto del cargo.*/
   If nvl(v_reg_loc.mto_comision,0) > 0 then
      v_secuencia := nvl( v_secuencia, 0 ) + 1;
      -- Recuperar el codigo y el valor de la tasa de la transaccion de comision
      prg_obt_cargos(pag_ser.g_cod_oficina, v_reg_loc.nro_cta_debito, pag_ser.g_cod_moneda, 999999,
                     pag_ser.g_cod_modulo, pag_ser.g_cod_modalidad, v_cod_Tra_comision,
                     v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto,
                     v_val_tas_impuesto, v_val_impuesto);

      pag_cta.pr_act_operacion( v_reg_loc.nro_cta_debito,        --P_NRO_CUENTA
                           pag_ser.g_hora,                  --P_HORA
                           'D',                             --P_TIP_MOVIMIENTO
                           v_reg_loc.cod_moneda,            --P_COD_MONEDA
                           v_reg_loc.mto_comision,          --P_MONTO
                           pag_ser.g_cod_transaccion,       --P_COD_TRA_PADRE
                           v_cod_tra_comision,              --P_COD_TRANSACCION
                           v_reg_loc.nro_operacion,         --P_NRO_DOCUMENTO
                           null,                            --P_COTIZACION
                           v_reg_loc.cod_ofi_origen,        --P_COD_OFI_ORIGEN
                           pag_ser.g_cod_modulo,            --P_COD_MOD_PADRE
                           pag_ser.g_cod_modalidad,         --P_COD_MAD_PADRE
                           v_cod_Tas_cargo,                 --P_COD_TASA
                           v_val_tas_cargo,                 --P_VAL_TASA
                           'Debito Comision cobro de servicio',  --P_CONCEPTO
                           'S',                             --P_EMI_AVISO
                           v_secuencia,                     --P_NRO_SECUENCIA
                           pag_ser.g_fecha,                 --P_FEC_VALOR
                           NULL,
                           NULL );
     -- Si se produjo un error, inserta el debito con errores.
     IF pag_cta.g_cod_error <> 0
     and (pag_cta.g_cod_error not in(25, 31, 29)
      or  (pag_cta.g_cod_error in(25, 31, 29) and v_cli_modalidad in (31,41))) then
        v_reg_loc.estado    := 'E';
        pag_ser.g_cod_error := pag_cta.g_cod_error;
        pag_ser.g_men_error := fug_obt_err_sueldos( pag_cta.g_cod_error, 'D' );
        IF nvl( p_tipo, 'I' ) = 'I' THEN--I es de deb auto
          -- Grabar movimiento con error
          pr_ins_cobro( v_reg_loc, pag_ser.g_cod_transaccion, 'P' );
        END IF;
        -- Finalizar la operacion
        raise v_error;
     end if;
 ----------------------------------------------------------------
   /* RI : 20/01/2010 : Intenta DEBITAR el iva de la comision */
   if  nvl(v_reg_loc.mto_impuesto,0) > 0 then
    -- busco el impuesto asociado al cargo de la comision
    begin
      select cod_tra_hijo
        into v_cod_tra_impuesto
        from ge_transacciones_det
       where cod_modulo = pag_ser.g_cod_modulo
         and cod_modalidad = pag_ser.g_cod_modalidad
         and cod_transaccion = v_cod_Tra_comision
         and cod_mod_hijo = pag_ser.g_cod_modulo
         and cod_mad_hijo = pag_ser.g_cod_modalidad
         and cod_tra_hijo <> v_cod_Tra_comision
         and rownum = 1;
      exception
        when no_Data_found then
         v_cod_tra_impuesto := null;
      end;
     ---
      v_secuencia := nvl( v_secuencia, 0 ) + 1;
      pag_cta.pr_act_operacion( v_reg_loc.nro_cta_debito,        --P_NRO_CUENTA
                           pag_ser.g_hora,                  --P_HORA
                           'D',                             --P_TIP_MOVIMIENTO
                           v_reg_loc.cod_moneda,            --P_COD_MONEDA
                           v_reg_loc.mto_impuesto,          --P_MONTO
                           pag_ser.g_cod_transaccion,       --P_COD_TRA_PADRE
                           v_cod_tra_impuesto,              --P_COD_TRANSACCION
                           v_reg_loc.nro_operacion,                 --P_NRO_DOCUMENTO
                           null,                            --P_COTIZACION
                           v_reg_loc.cod_ofi_origen,        --P_COD_OFI_ORIGEN
                           pag_ser.g_cod_modulo,            --P_COD_MOD_PADRE
                           pag_ser.g_cod_modalidad,         --P_COD_MAD_PADRE
                           v_cod_tas_impuesto,              --P_COD_TASA
                           v_val_tas_impuesto,              --P_VAL_TASA
                           'IVA s/ Comision cobro de servicio',  --P_CONCEPTO
                           'S',                             --P_EMI_AVISO
                           v_secuencia,                     --P_NRO_SECUENCIA
                           pag_ser.g_fecha,                 --P_FEC_VALOR
                           NULL,
                           NULL );
     -- Si se produjo un error, inserta el debito con errores.
     IF pag_cta.g_cod_error <> 0
   and (pag_cta.g_cod_error not in(25, 31, 29)
    or  (pag_cta.g_cod_error in(25, 31, 29) and v_cli_modalidad in (31,41))) then
        v_reg_loc.estado    := 'E';
        pag_ser.g_cod_error := pag_cta.g_cod_error;
        pag_ser.g_men_error := fug_obt_err_sueldos( pag_cta.g_cod_error, 'D' );
        IF nvl( p_tipo, 'I' ) = 'I' THEN--I es de deb auto
          -- Grabar movimiento con error
          pr_ins_cobro( v_reg_loc, pag_ser.g_cod_transaccion, 'P' );
        END IF;
        -- Finalizar la operacion
        raise v_error;
     end if;
    end if;
    /*
    || PCC-Exoneración y Extorno de Comisiones y Tasas
    || Se ejecuta si el proceso no es mensual
    || o la base de datos no es producción
    */
    IF g_fre_proceso <> 'M' OR g_db_prod = 'N' THEN
       -- busco el valor de la tasa
       begin
          v_val_exo_cargo := fug_obt_val_tasa(pag_ser.g_cod_modulo,
                                              pag_ser.g_cod_modalidad,
                                              pag_ser.g_cod_oficina,
                                              null,
                                              pag_ser.g_cod_moneda,
                                              0, 'N', NULL,
                                              pag_ser.g_cod_transaccion,
                                              pag_ser.g_fecha);
       exception
          when others then
             raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
       end;
       v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_cargo);
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                       pag_ser.g_cod_modulo,
                                       pag_ser.g_cod_modalidad,
                                       pag_ser.g_cod_moneda);
       IF v_tip_valor = 'V' THEN
          -- si es un valor, se toma directamente
          v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
       ELSE
          -- es un porcentaje
          v_val_exo_cargo := round(nvl(999999, 0) * nvl(v_val_exo_cargo, 0) / 100, v_redondeo);
          --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
          v_val_exo_cargo := pag_gen.fu_obt_val_final(v_val_exo_cargo);
       END IF;
       if pag_cta.fu_ver_tra_prohibida(v_reg_loc.nro_cta_debito,
                                       pag_ser.g_cod_transaccion,
                                       pag_ser.g_cod_modulo,
                                       pag_ser.g_cod_modalidad) = 'S' then
          prg_ins_exoneracion(pag_ser.g_cod_transaccion, pag_ser.g_cod_modulo,
                              pag_ser.g_cod_modalidad, pag_ser.g_cod_moneda,
                              v_reg_loc.nro_cta_debito, null, v_cod_tas_cargo,
                              nvl(v_val_exo_cargo, 0),
                              nvl(v_val_exo_cargo, 0), null,
                              nvl(v_val_exo_cargo, 0));
       elsif (nvl(v_val_cargo, 0) <> nvl(v_val_exo_cargo, 0)) or
             (nvl(v_val_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
          prg_ins_exoneracion(pag_ser.g_cod_transaccion, pag_ser.g_cod_modulo,
                              pag_ser.g_cod_modalidad, pag_ser.g_cod_moneda,
                              v_reg_loc.nro_cta_debito, null, v_cod_tas_cargo,
                              (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)),
                               nvl(v_val_exo_cargo, 0), null,
                              (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)));
       end if;
       begin
          v_val_exo_impuesto := fug_obt_val_tasa(pag_ser.g_cod_modulo,
                                                 pag_ser.g_cod_modalidad,
                                                 pag_ser.g_cod_oficina,
                                                 null,
                                                 pag_ser.g_cod_moneda,
                                                 0, 'N', NULL,
                                                 v_cod_tra_impuesto,
                                                 pag_ser.g_fecha);
       exception
          when others then
             raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
       end;
       IF v_tip_valor = 'V' THEN
          -- si es un valor, se toma directamente
          v_val_exo_impuesto := nvl(v_val_exo_impuesto, 0);
       ELSE
          -- es un porcentaje, se considera incluido en el cargo
          v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_exo_impuesto, 0) /
                                 (100 + v_val_exo_impuesto), v_redondeo);
          --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
          v_val_exo_impuesto := pag_gen.fu_obt_val_final(v_val_exo_impuesto);
       END IF;
       if pag_cta.fu_ver_tra_prohibida(v_reg_loc.nro_cta_debito,
                                       v_cod_tra_impuesto,
                                       pag_ser.g_cod_modulo,
                                       pag_ser.g_cod_modalidad) = 'S' then
          prg_ins_exoneracion(v_cod_tra_impuesto, pag_ser.g_cod_modulo,
                              pag_ser.g_cod_modalidad, pag_ser.g_cod_moneda,
                              v_reg_loc.nro_cta_debito, null, v_cod_tas_impuesto,
                              (nvl(v_val_impuesto, 0) - nvl(v_val_exo_impuesto, 0)),
                               v_val_exo_impuesto, null,
                              (nvl(v_val_impuesto, 0) - nvl(v_val_exo_impuesto, 0)));
       elsif pag_cta.fu_ver_tra_prohibida(v_reg_loc.nro_cta_debito,
                                       pag_ser.g_cod_transaccion,
                                       pag_ser.g_cod_modulo,
                                       pag_ser.g_cod_modalidad) = 'S' then
          null;
       elsif (nvl(v_val_impuesto, 0) <> nvl(v_val_exo_impuesto, 0)) or
             (nvl(v_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
          prg_ins_exoneracion(v_cod_tra_impuesto, pag_ser.g_cod_modulo,
                              pag_ser.g_cod_modalidad, pag_ser.g_cod_moneda,
                              v_reg_loc.nro_cta_debito, null, v_cod_tas_impuesto,
                              (nvl(v_val_impuesto, 0) - nvl(v_val_exo_impuesto, 0)),
                               v_val_exo_impuesto, null,
                              (nvl(v_val_impuesto, 0) - nvl(v_val_exo_impuesto, 0)));
       end if;
    end if;
    ---
   END IF;
   /************************************** C R E D I T O **************************************/
   -- Intenta ACREDITAR los cargos en la cuenta del proveedor del servicio.
   -- Primero asigna el siguiente numero a la secuencia.
   v_secuencia := nvl( v_secuencia, 0 ) + 1;
   pag_cta.pr_act_operacion( pag_ser.g_nro_cuenta,            --P_NRO_CUENTA
                           pag_ser.g_hora,                  --P_HORA
                           'C',                             --P_TIP_MOVIMIENTO
                           v_reg_loc.cod_moneda,            --P_COD_MONEDA
                           v_reg_loc.monto,                 --P_MONTO
                           pag_ser.g_cod_transaccion,       --P_COD_TRA_PADRE
                           602,                             --P_COD_TRANSACCION
                           v_reg_loc.nro_operacion,                 --P_NRO_DOCUMENTO
                           null,                            --P_COTIZACION
                           v_reg_loc.cod_ofi_origen,        --P_COD_OFI_ORIGEN
                           pag_ser.g_cod_modulo,            --P_COD_MOD_PADRE
                           pag_ser.g_cod_modalidad,         --P_COD_MAD_PADRE
                           NULL,                            --P_COD_TASA
                           NULL,                            --P_VAL_TASA
                           'Credito Automatico p/ Cobros',  --P_CONCEPTO
                           'S',                             --P_EMI_AVISO
                           v_secuencia,                     --P_NRO_SECUENCIA
                           pag_ser.g_fecha,                 --P_FEC_VALOR
                           NULL,
                           NULL );
   -- Si se produjo un error, inserta el debito con errores.
   IF pag_cta.g_cod_error <> 0 THEN
      v_reg_loc.estado    := 'E';
      pag_ser.g_cod_error := pag_cta.g_cod_error;
      pag_ser.g_men_error := fug_obt_err_sueldos( pag_cta.g_cod_error, 'D' );
      IF nvl( p_tipo, 'I' ) = 'I' THEN--I es de deb auto
        -- Grabar movimiento con error
        pr_ins_cobro( v_reg_loc, pag_ser.g_cod_transaccion, 'P' );
      END IF;
      -- Finalizar la operacion
      raise v_error;
   END IF;
   v_reg_loc.estado    := 'P';
   pag_ser.g_cod_error := 0;
   pag_ser.g_men_error := NULL;
   IF nvl( p_tipo, 'I' ) = 'I' THEN--I es de deb auto
      --- Grabar movimiento
      pr_ins_cobro( v_reg_loc, pag_ser.g_cod_transaccion, 'P' );
   END IF;
EXCEPTION
   when v_error then
      IF sqlcode <= -20000 THEN
        RAISE;
      ELSE
        NULL;
      END IF;
   when others then
      IF sqlcode <= -20000 THEN
        pag_ser.g_cod_error := -20405;
        pag_ser.g_men_error := 'Intento de cobro.' || sqlerrm;
--        RAISE;
      ELSE
        pag_ser.g_cod_error := -20405;
        pag_ser.g_men_error := 'Error al intentar cobrar el servicio ' || sqlerrm;
      END IF;
END;

PROCEDURE pr_pro_deb_automatico IS
 /* || Proceso de debito automatico.
 || el proceso busca todos los servicios que esten marcados como
 || Debito Automatico [deb_automatico='S'], y luego procesa
 || las cuentas asociadas a ese servicio, que esten autorizadas y cuya
 || frecuencia coincida con el dia de hoy.
 || Si la cuenta esta marcada como cuotas [tipo = 'P'], entonces procesa
 || las cuotas pendientes que aun no se hayan pagado y cuya fecha de
 || vencimiento sea igual al dia de hoy
 || * PPalella ==> 02/08/2005 */
CURSOR servicios IS
  select p.cod_servicio
  from ge_cob_ser_parametros p, ge_cuentas g
  where nvl(p.deb_automatico, 'N') = 'S'
        and p.nro_cuenta = g.nro_cuenta
  order by p.cod_servicio;

CURSOR cuentas( p_cod_servicio VARCHAR2 ) IS
  select t.nro_cuenta, null nro_cuota, t.fec_vencimiento, t.tipo, t.monto, t.referencia,
      g.cod_modulo, g.cod_modalidad, g.cod_oficina, g.cod_moneda
  from ge_cob_ser_cuentas t, ge_cuentas g
  where t.cod_servicio = p_cod_servicio
  and nvl(t.autorizado, 'N') = 'S'
  and t.tipo not in ('M','P')--manual no xq se hace x ascii, x cuotas se hace abajo
  and pag_cal.g_fec_actual between t.fec_inicio  and nvl(t.fec_vencimiento, to_date('31/12/9999', 'DD/MM/YYYY' ))
  and fug_pue_cobrar(t.frecuencia, t.fre_dia) ='S'
  and t.nro_cuenta = g.nro_cuenta
  --no pagadas en el dia, q no se haya corrido el proceso
  and not exists (select 0
                  from ge_cob_servicios x
                  where x.cod_servicio = t.cod_servicio
                  and x.nro_cta_debito = t.nro_cuenta
                  and x.referencia1 = t.referencia
                  and x.fecha = pag_cal.g_fec_actual)
UNION
  select a.nro_cuenta, nro_cuota, a.fec_vencimiento, 'P' tipo, monto, a.referencia referencia,
    g.cod_modulo, g.cod_modalidad, g.cod_oficina, g.cod_moneda
  from ge_cob_ser_cuotas a, ge_cuentas g
  where cod_servicio = p_cod_servicio
  and a.nro_cuenta = g.nro_cuenta
  and fec_cobro is null
  and a.estado <> 'P' --no pagadas
  and a.fec_vencimiento >= pag_cal.g_fec_actual
  and a.fec_vencimiento < pag_cal.g_fec_proxima
  and a.nro_cuenta in (select t.nro_cuenta
                      from ge_cob_ser_cuentas t, ge_cuentas g
                      where t.cod_servicio = p_cod_servicio
                      and nvl(t.autorizado, 'N') = 'S'
                      and t.referencia = a.referencia
                      and t.tipo in ('P') --solo x cuotas
                      and pag_cal.g_fec_actual between t.fec_inicio and nvl(t.fec_vencimiento, to_date('31/12/9999', 'DD/MM/YYYY' ))
                      and fug_pue_cobrar(t.frecuencia, t.fre_dia) ='S'--siempre puede xq son diarias
                      and t.nro_cuenta = g.nro_cuenta
                      --no pagadas en el dia, q no se haya corrido el proceso
                      and not exists (select 0
                                      from ge_cob_servicios x
                                      where x.cod_servicio = t.cod_servicio
                                      and x.nro_cta_debito = t.nro_cuenta
                                      and x.referencia1 = t.referencia
                                      and x.fecha = pag_cal.g_fec_actual))
 order by nro_cuota;
 r_cobro GE_COB_SERVICIOS%ROWTYPE;
BEGIN
   --obtener datos del calendario
   pag_cal.pr_obt_dat_calendar(1);
   --iniciliza las variables de error
   pag_ser.pr_ini_variables;
   -- Inicializa la fecha y la hora
   pag_ser.g_fecha := pag_cal.G_FEC_ACTUAL;
   pag_ser.g_hora  := to_char( sysdate, 'HH24:MI:SS' );
   FOR s IN servicios LOOP
      FOR c IN cuentas( s.cod_servicio ) LOOP
        pag_ser.g_cod_error := 0;
        pag_ser.g_men_error := NULL;
        IF c.tipo = 'F' THEN --> Monto fijo por periodo
            r_cobro := NULL;
            -- Para grabar por cada registro procesado y sus movimientos la misma hora
            --pag_ser.g_hora := pag_gen.fu_obt_sig_segundo( pag_ser.g_hora );
            -- DDSI-265 -- 02/2018 : Se cambia para buscar una hora disponible
            pag_ser.g_hora := fug_obt_hor_disponible(pag_ser.g_fecha, pag_ser.g_hora, user, 'N' );
            -- Inicializar los campos
            r_cobro.cod_servicio    := s.cod_servicio;
            if r_cobro.tip_cobro is null then
             r_cobro.tip_cobro       := 'P';
            end if;
            r_cobro.fecha           := pag_ser.g_fecha;
            r_cobro.hora            := pag_ser.g_hora;
            r_cobro.referencia1     := c.referencia;
            r_cobro.monto           := c.monto;
            r_cobro.cod_moneda      := c.cod_moneda;
            r_cobro.mto_debito      := c.monto;
            r_cobro.nro_cta_debito  := c.nro_cuenta;
            r_cobro.cod_usuario     := user;
            -- Procesa el cobro de la cuenta
            pag_ser.pr_pro_debito( r_cobro );
        ELSIF c.tipo = 'P' THEN --> Por cuotas
          --FOR t IN cuotas( s.cod_servicio, c.nro_cuenta ) LOOP
            r_cobro := NULL;
            -- Para grabar por cada registro procesado y sus movimientos la misma hora
            --pag_ser.g_hora := pag_gen.fu_obt_sig_segundo( pag_ser.g_hora );
            -- DDSI-265 -- 02/2018 : Se cambia para buscar una hora disponible
            pag_ser.g_hora := fug_obt_hor_disponible(pag_ser.g_fecha, pag_ser.g_hora, user, 'N' );
            -- Inicializar los campos
            r_cobro.cod_servicio    := s.cod_servicio;
            if r_cobro.tip_cobro is null then
               r_cobro.tip_cobro       := 'P';
            end if;
            r_cobro.fecha           := pag_ser.g_fecha;
            r_cobro.hora            := pag_ser.g_hora;
            r_cobro.referencia1     := c.referencia;
            r_cobro.monto           := c.monto;
            r_cobro.cod_moneda      := c.cod_moneda;
            r_cobro.mto_debito      := c.monto;
            r_cobro.nro_cta_debito  := c.nro_cuenta;
            r_cobro.nro_cuota       := c.nro_cuota;
            r_cobro.cod_usuario     := user;
            -- Procesa el cobro de la cuenta
            pag_ser.pr_pro_debito( r_cobro );
            -- solo si fue sin error, actualizar las cuotas
            if nvl(pag_ser.g_cod_error,0) = 0 then
              update ge_cob_ser_cuotas
                 set estado = 'P',
                     fec_cobro = pag_ser.g_fecha
               where nro_cuenta = c.nro_cuenta
                 and nro_cuota = c.nro_cuota
                 and ((referencia = c.referencia) or (referencia is null and c.referencia is null))
                 and cod_servicio = s.cod_servicio;--current of cuotas;
            end if;
          --END LOOP;
        END IF;
        pag_ser.g_cod_error := 0;
        pag_ser.g_men_error := NULL;
      END LOOP;
   END LOOP;
EXCEPTION
   when others then
      IF sqlcode <= -20000 THEN
        RAISE;
      ELSE
        RAISE_APPLICATION_ERROR( -20310, 'ERROR. En el proceso de debitos automaticos ' || sqlerrm );
      END IF;
END pr_pro_deb_automatico;

PROCEDURE pr_obt_servicio( p_cod_servicio IN  GE_COB_SER_PARAMETROS.COD_SERVICIO%TYPE ) IS
 /*
 || Procedimiento que busca los datos del servicio y los carga en
 || las globales del paquete.
 || * PPalella ==> 02/08/2005
 */
 v_cod_modulo      GE_CUENTAS.COD_MODULO%TYPE;
 v_cod_modalidad   GE_CUENTAS.COD_MODALIDAD%TYPE;
 v_cod_oficina     GE_CUENTAS.COD_OFICINA%TYPE;
 v_nro_cuenta      GE_CUENTAS.NRO_CUENTA%TYPE;
 v_cod_moneda      GE_CUENTAS.COD_MONEDA%TYPE;
 v_cod_transaccion GE_TRANSACCIONES.COD_TRANSACCION%TYPE;
 v_for_referencia  ge_cob_ser_parametros.for_campo1%type;
BEGIN
   BEGIN
      select p.cod_modulo, p.cod_modalidad, p.cod_oficina, p.nro_cuenta, c.cod_moneda,
             p.cod_transaccion, p.for_campo1
        into v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_nro_cuenta, v_cod_moneda,
             v_cod_transaccion, v_for_referencia
        from ge_cob_ser_parametros p, ge_cuentas c
       where p.cod_servicio = p_cod_servicio
         and p.nro_cuenta = c.nro_cuenta;
   EXCEPTION
      when others then
        v_cod_modulo      := NULL;
        v_cod_modalidad   := NULL;
        v_cod_oficina     := NULL;
        v_nro_cuenta      := NULL;
        v_cod_moneda      := NULL;
        v_cod_transaccion := NULL;
        v_for_referencia  := null;
        pag_ser.g_cod_error := -20901;
        pag_ser.g_men_error := 'Error al buscar los datos del servicio ' || p_cod_servicio || '; ' || sqlcode;
   END;
   pag_ser.g_cod_modulo      := v_cod_modulo;
   pag_ser.g_cod_modalidad   := v_cod_modalidad;
   pag_ser.g_cod_oficina     := v_cod_oficina;
   pag_ser.g_nro_cuenta      := v_nro_cuenta;
   pag_ser.g_cod_moneda      := v_cod_moneda;
   pag_ser.g_cod_transaccion := v_cod_transaccion;
   pag_ser.g_for_referencia  := v_for_referencia;
END;

FUNCTION fu_obt_error( p_cod_error OUT VARCHAR2,
                      p_men_error OUT VARCHAR2
                      ) RETURN BOOLEAN IS
 /*
 || Funcion utilizada para verificar si se produjeron errores
 ||  en los procesos
 || * PPalella ==> 02/08/2005
 */
BEGIN
   IF pag_ser.g_cod_error <> 0 OR
      pag_ser.g_men_error IS NOT NULL THEN
      p_cod_error := pag_ser.g_cod_error;
      p_men_error := pag_ser.g_men_error;
      return TRUE;
   ELSE
      p_cod_error := NULL;
      p_men_error := NULL;
      return FALSE;
   END IF;
END;

FUNCTION fu_obt_mon_servicio
RETURN varchar2 IS
 /*devuelve la moneda de la cuenta de credito del servicio*/
BEGIN
  return pag_ser.g_cod_moneda;
END;

PROCEDURE pr_ini_variables
is
/*Procedimiento que inicializa las variables de error*/
begin
   pag_ser.g_cod_error := NULL;
   pag_ser.g_men_error := NULL;
end;

/*Procedimiento que verifica si hay datos pendientes de ser procesados*/
--si existen devuelve S y
--1: pendientes en ge_cob_servicios
--2: pendientes en ge_cob_servicios_tmp
PROCEDURE pr_ver_cob_pendientes
(p_cod_servicio IN  GE_COB_SER_PARAMETROS.COD_SERVICIO%TYPE,
 p_cod_usuario in ge_cob_servicios.cod_usuario%type,
 p_fecha in ge_cob_servicios.fecha%type,
 p_cod_oficina ge_cob_servicios.cod_ofi_origen%type,
 p_existe out varchar2,
 p_ind_archivo out number)
is
v_existe number := 0;
begin
   --ver si hay pendientes de procesar para la oficina
   select nvl(count(*),0)
     into v_existe
     from ge_cob_servicios
    where tip_cobro ='A'
      and estado <> 'P'
      and fecha = p_fecha
      and cod_servicio = p_cod_servicio
      and cod_ofi_origen = p_cod_oficina;
   if v_existe > 0 then
      p_existe      := 'S';
      p_ind_archivo := 1;
   else
      p_existe :='N';
      begin
         --buscar en el tmp por el usuario
         select nvl(count(*),0)
           into v_existe
           from ge_cob_servicios_tmp
          where fecha = p_fecha
            and cod_servicio = p_cod_servicio
            and cod_ofi_origen = p_cod_oficina;
         if v_existe > 0 then
            p_existe      := 'S';
            p_ind_archivo := 2;
         end if;
      exception
         when others then
            raise_application_error(-20401,'Recup.Pendientes Ge_Cob_Servicios_Tmp '||sqlerrm);
      end;
   end if;
exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20400,'Recup.Pendientes Ge_Cob_Servicios. '||sqlerrm);
      end if;
end;


procedure lp_ver_horario is
    v_est_modulo ba_modulos.estado%type;

  begin
    v_horario := 'D'; -- Dia normal
    v_es_mov_noc  := 'N'; -- Para grabar en las tablas nocturnas
    v_es_cta_noc  := 'N';
    -- Debe recuperar del módulo de Caja. CB. 20/11/2013. DYDMR-10
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(9);
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(9);

   IF v_est_modulo in (1,6) THEN      -- En cierre.
       pag_ser.v_cod_respuesta := -1;
       v_msj_respuesta := 'Sistema en cierre';
    elsif v_est_modulo = 2 Then -- El modulo esta abierto
       -- Verifica la hora --
       null;
    else
       v_es_mov_noc  := 'S'; -- Para grabar en las tablas nocturnas
       v_horario := 'N'; -- Noche
       v_fec_actual := pag_cal.FU_OBT_FEC_PROXIMA(3);
       v_es_cta_noc  := 'S'; -- Solo para que llavee la cuenta nocturna
    end if;
    v_fec_valor       := trunc(sysdate);--v_fec_actual;
    pag_cta.g_horario := v_horario;
  end lp_ver_horario;

FUNCTION lf_val_sesion    ( p_nro_sesion  IN varchar2,
                            p_nro_ip      IN varchar2,
                            p_cuenta      IN varchar2 ) RETURN VARCHAR2 IS

 v_existe          varchar2(1) := 'N';
 v_tot_operaciones number(3);
 v_max_tiempo      number(3) := null;
 v_max_pagos       number(3) := null;
BEGIN
   -- tiempo máximo de sesión válida
   begin
     v_max_tiempo := nvl(to_number(trim(fug_obt_pardinamico('MAX_TPO_SER_SESION'))), 15);
   exception
     when others then
       v_max_tiempo := 15; -- por defecto 15 minutos
   end;
   -- cantidad máxima de pagos por sesión
   begin
     v_max_pagos := nvl(to_number(trim(fug_obt_pardinamico('MAX_OPE_SER_SESION'))), 3);
   exception
     when others then
       v_max_pagos := 3; -- por defecto, máximo 3 pagos
   end;
   select decode(nvl(count(*), 0), 0, 'N', 'S'), a.can_operaciones
     into v_existe, v_tot_operaciones
     from bw_sesiones a
    where a.nro_sesion = p_nro_sesion
      and a.nro_ip = p_nro_ip
      and a.nro_cuenta = p_cuenta
      and (sysdate - a.fec_insercion)*1440 <= v_max_tiempo
      and a.can_operaciones < v_max_pagos
    group by a.can_operaciones;
   return v_existe;
EXCEPTION
   when others then
      pag_ser.g_cod_error := -20111;
      pag_ser.g_men_error := 'No se pudo verificar la sesion '||sqlerrm;
      return 'N';
END;

/* verifica que la operación sea repetida */
FUNCTION lf_ver_transaccion(p_nro_cuenta   IN bw_pag_servicios.nro_cuenta%TYPE,
                            p_monto        IN bw_pag_servicios.mto_transaccion%TYPE,
                            p_cod_servicio IN bw_pag_servicios.cod_servicio%TYPE) RETURN VARCHAR2 IS
v_existe         VARCHAR2(1);
--v_cantidad       NUMBER;
v_min_transacion NUMBER := nvl(to_number(fug_obt_pardinamico('PAW_MIN_TRANSACCION')), 10);
BEGIN
  begin
    select 'S'
      into v_existe
      from bw_pag_servicios bp
     where bp.nro_cuenta = p_nro_cuenta
       and bp.mto_debito = p_monto
       and bp.cod_servicio = p_cod_servicio
       and nvl(bp.reversado, 'N') = 'N'
       and ((sysdate) -bp.fec_insercion)*1440 <= v_min_transacion;
  exception
    when no_data_found then
      v_existe := 'N';
    when too_many_rows then
      v_existe := 'S';
  end;
  return v_existe;
END;

/*verifica los datos del tmp y procesa si no hay errores*/
PROCEDURE pr_ver_dat_temporales
(p_cod_ente in ge_cob_ser_parametros.cod_servicio%type,
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
  v_cod_mon_debito  ah_cta_vistas.cod_moneda%type;
  v_concepto        ge_cob_ser_privados.error%type;
  v_nombre           varchar2(50);
  v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_descripcion      ge_entes.descripcion%type;
  v_cod_tra_padre    ge_transacciones.cod_transaccion%type;
  v_cta_debito       ge_cuentas.nro_cuenta%type;
  v_ref_archivo      ge_archivos.referencia%type;
  v_cod_tra_debito   ge_transacciones.cod_transaccion%type;
  v_todetal  number(18,2);
  v_tocabec  number(18,2);
  v_cod_oficina      ba_oficinas.cod_oficina%type;
  v_existe           varchar2(1);
  v_nom_persona      ba_personas.nom_completo%type;
  v_tot_factura      number(18,2);
  v_cta_credito      ge_cuentas.nro_cuenta%type;
  v_Exi_Cta          number;
  v_exi_cta_deb      number;
  v_sum_monto        number;
  v_sal_disponible   number;
  v_procesa          varchar2(1) := 'N';

  cursor c_tmp is
    select *
      from ge_cob_ser_privados_tmp
     where trunc(fec_insercion) = trunc(sysdate)
       and usu_insercion = user
       and cod_servicio = p_cod_ente
       and nvl(tipo,'D') = 'D'
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
  --- Traer datos de parametros de servicios
  Begin
     select p.cod_transaccion
       into v_cod_Tra_padre
       from ge_cob_ser_parametros p
      where p.cod_servicio = p_cod_ente;
  Exception
    when others then
        p_error := 'Recep.Parametro de servicios ' ||sqlerrm;
        return;
  End;
  --actualiza los datos basicos del tmp para poder verificar, solo si no actualizo antes
  begin
     update ge_cob_ser_privados_tmp set
         estado             = 'C',        --- cargado
         fec_proceso        = v_fec_actual,
         cod_usuario        = user,
         cod_servicio       = p_cod_ente
      where trunc(fec_insercion) = trunc(sysdate)
       and usu_insercion = user --por el usuario
       and cod_servicio is null;
  exception
     when others then
        p_error := 'Actualizar TMP de Cobro de servicios.'||sqlerrm;
        return;
  end;
  -- Trae datos de cuenta de credito
  v_cod_proceso := 0;
  v_concepto := null;
  Begin
     select c.nro_cuenta, c.cod_moneda
       into v_cta_credito, v_cod_moneda
       from ge_cuentas c, ge_cob_ser_privados_tmp t
      where cod_servicio  = p_cod_ente
        and fec_proceso = v_fec_actual
        and cod_usuario = user
        and tipo = 'C'
        and c.nro_cuenta = t.nro_cuenta;
     --
     Begin
        Select 'S' into v_existe
          from ge_cta_clientes
         where nro_cuenta = v_cta_credito
           and relacion = 'P';
     Exception
         when others then
           v_cod_proceso := 12;
           p_error := 'Cuenta de Credito en GE_CTA_CLIENTES. '||sqlerrm;
     end;
  Exception
    when no_data_found then
        v_cod_proceso := 12;
        p_error := 'No existe cuenta de Credito en TMP.'||sqlerrm;
    when others then
        v_cod_proceso := 12;
        p_error       := 'Al verificar cta. credito : '||sqlerrm;
  end;
  begin
     update ge_cob_ser_privados_tmp set
            cod_proceso        = v_cod_proceso,
            error              = p_error,
            cod_moneda          = v_cod_moneda
      where cod_servicio = p_cod_ente
        and fec_proceso   = v_fec_actual
        and cod_usuario   = user
        and nro_cuenta = v_cta_credito;
    exception
      when others then
         p_error := 'Al actualizar TMP :'||sqlerrm;
         return;
    end;
  -- Verifico si no se realizo el mismo pago en la misma fecha
/*  Declare
   cursor c_deb is
    Select t.nro_cuenta, sum(monto) monto
      from ge_cob_ser_privados_tmp t
     where cod_ente = p_cod_ente
       and trunc(fec_insercion) = v_Fec_actual
       and tipo = 'D'
    group by nro_cuenta;
  Begin
   For reg in c_deb loop
      Select sum(monto) into v_sum_monto
        from ge_cob_ser_privados p
       where p.cod_ente = p_cod_ente
         and p.fec_proceso = v_fec_actual
         and p.nro_cuenta = reg.nro_cuenta;
      if  v_sum_monto = reg.monto then
         p_error := 'Ya se realizo este pago en la fecha.';
         return;
      end if;
    end loop;
   End;
  */
  --verifica q haya datos
  v_cod_proceso := 0;
  v_concepto := null;
  v_existe   := 'N';
  for reg in c_tmp loop
    v_existe := 'S';
    exit;
  end loop;
  if v_existe is null then
    p_error := 'No existen datos cargados en el tmp. Verifique';
    return;
  end if;

  --recorre los registros del temporal para verificar datos: cta.debito, , etc
  for reg in c_tmp loop
    v_concepto     := 'Cobro cuenta '||reg.nro_cuenta;
    v_cod_proceso := 0;
    --limpiar variables
    v_cod_mon_debito := null;
    v_estado     := null;
    v_cod_modulo := null;
    v_cod_modalidad := null;
    v_cta_combinada := null;

        pag_cta.pr_obt_cuenta(reg.nro_cuenta);
        if pag_cta.fu_obt_cod_error() <> 0 then
           v_concepto := substr(pag_cta.fu_obt_msj_error(),1,40);
           v_cod_proceso := 51;
        end if;
        select count(*) into v_exi_cta
          from ge_cuentas
         where nro_cuenta = reg.nro_cuenta;
        if  v_exi_Cta = 0 then
           v_concepto := 'CUENTA NO EXISTE EN GE_CUENTAS';
           v_cod_proceso := 51;
        end if;
        v_cod_mon_debito := pag_cta.g_ctas.cod_moneda;
        v_estado     := pag_cta.g_ctas.estado;
        v_cod_modulo := pag_cta.G_CTAS.cod_modulo;
        v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
        v_cta_combinada := pag_cta.g_ctas.cta_combinada;
        --- si es cta ahorro o cta cte
         if v_cod_modalidad not in (31,41) THEN
            v_concepto     := 'MODALIDAD DE LA CUENTA INVALIDO';
            v_cod_proceso := 52;
         end if;
        if v_estado is null then
           v_concepto := 'ESTADO INVALIDO';
           v_cod_proceso := 53;
        end if;
        if v_estado IN ('C','T') THEN
          v_concepto     := 'ESTADO DE LA CUENTA INVALIDO';
          v_cod_proceso := 55;
        end if;
         if v_cod_moneda <> v_cod_mon_debito then
            v_concepto     := 'MONEDA CTA CREDITO <> MONEDA CTA DEBITO';
            v_cod_proceso := 56;
         end if;
         --obtener principal de cuenta
         begin
           v_nom_persona := fue_obt_nom_persona(fug_obt_cli_principal(reg.nro_cuenta));
         exception
           when others then
              if substr(sqlerrm,1,3)='ORA' then
                v_concepto  := substr(SQLERRM,12,40);
              ELSE
                v_concepto  := substr(SQLERRM,1,40);
              end if;
              v_cod_proceso :=57;
         end;

   --Valido la moneda del txt con la moneda de la cuenta de debito del ente
    if reg.cod_moneda <> v_cod_moneda then
      v_concepto := 'MONEDA NO CORESPONDE A LA CTA. DE CREDITO';
      v_cod_proceso := 69;
    end if;

    --- Valido que tenga saldo suficiente para el debito
    pag_cta.pr_ver_operacion(reg.nro_cuenta,
                             v_cod_Tra_padre,
                                    v_cod_modulo,
                                    v_cod_modalidad,
                                    'D',
                                    v_cod_mon_debito,
                                    reg.monto,
                                    v_cod_oficina,
                                    v_cod_modulo,
                                    v_cod_modalidad,
                                    v_estado,
                                    v_sal_disponible,
                                    v_procesa,
                                    503);
              if v_procesa = 'N' then
                 v_cod_proceso := 25;
                v_concepto := SUBstr(pag_cta.fu_obt_msj_error(),1,100);
              end if;

    ---- actualiza los datos que faltan en el tmp antes de pasar a GE_COB_SER_PRIVADOS
    begin
       update ge_cob_ser_privados_tmp set
           cod_proceso        = v_cod_proceso,
           error              = v_concepto,
           cod_moneda          = nvl(reg.cod_moneda,v_cod_mon_debito)
        where current of c_tmp ;
        if sql%notfound then
          p_error := 'No encontro registro a actualizar en TMP ';
          exit;
        end if;
    exception
      when others then
         p_error := 'Al actualizar TMP :'||sqlerrm;
         exit;
    end;
  end loop;

  if p_error is null then
    commit; --para q inserte en los tmp
  end if;

  -- ver si hubo error en los datos del tmp
  select count(*)
    into v_cant
    from ge_cob_ser_privados_tmp
   where cod_proceso <> 0
     and usu_insercion = user
     and trunc(fec_insercion) = trunc(sysdate)
     and cod_servicio = p_cod_ente;
--     and NVL(tipo,'D') = 'D';

   if v_cant > 0 then
      p_error := 'Errores en la verificacion de datos.';
   else
      p_error := null;
   end if;

  --procesar si no tiene errores, cargar en las tablas definitivas
  if p_error is null and p_procesar = 'S' then
    --proceso
    PAG_SER.PR_INS_GE_COB_SER_PRIVADOS(p_cod_ente, v_fec_actual, p_error);
    if p_error is not null then
      return;
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
        raise_application_error (-20000,'Verif.Datos Pag.Ser. '||sqlerrm);
      end if;
end PR_VER_DAT_TEMPORALES;


/*Función que obtiene la cuenta de debito a partir de la referencia recibida */
FUNCTION fu_obt_cta_debito
(p_cod_servicio IN  GE_COB_SER_PARAMETROS.COD_SERVICIO%TYPE,
 p_referencia   in  ge_cob_ser_cuentas.referencia%type)
RETURN VARCHAR2
is
 v_nro_cuenta  ge_cuentas.nro_cuenta%type;
BEGIN
  Begin
    Select nro_cuenta
      into v_nro_cuenta
      from ge_cob_ser_cuentas c
     where c.cod_servicio = p_cod_servicio
       and c.referencia   = p_referencia;
  Exception
    when no_Data_found then
       v_nro_cuenta := null;
    when too_many_rows then
       raise_application_error(-20400,'Fu_obt_cta_Debito : La función recupera mas de una final para la referencia : '||p_referencia||' del Servicio : '||p_cod_servicio);
  End;
  return v_nro_cuenta;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20400,'Error. Fu_obt_cta_Debito : Servicio: '||p_cod_servicio||' Referencia  : '||p_referencia||' - '||sqlerrm);
END;

FUNCTION fu_obt_deu_prestamo(p_nro_cuenta IN pr_cuotas.nro_cuenta%TYPE,
                               p_moneda     IN ba_monedas.cod_mon_bco_central%TYPE
                               --p_cod_moneda      IN pr_cta_prestamos.cod_moneda%TYPE nr
                               --p_tip_transaccion IN bw_pag_servicios.nro_transaccion%TYPE, nr
                               --p_cod_servicio    IN bw_pag_servicios.cod_servicio%TYPE nr
                               --) RETURN LONG IS nr
                               ) RETURN varchar2 IS
    --Datos de la cabecera.
    v_cod_tra_padre ge_movimientos.cod_tra_padre%TYPE := 360;
    v_nom_titular   BA_PERSONAS.NOM_COMPLETO%TYPE;
    v_can_cuotas    NUMBER(3);
    --v_cadena        LONG; nr
    v_cadena       VARCHAR2(32767);
    v_cad_cabecera VARCHAR2(5000);
    -- variables
    v_mto_cobrado        NUMBER(18, 2); -- Mto cobrado (no se despliega)
    v_tot_capital        NUMBER(18, 2); -- Capital (no se despliega )
    v_tot_interes        NUMBER(18, 2); -- Interes (no se despliega )
    v_tot_int_adelantado NUMBER(18, 2); -- Interes adelantado (no despliega)
    v_tot_mora           NUMBER(18, 2); -- Mora s/capital (no despliega)
    v_tot_moratorio      NUMBER(18, 2); -- Mora s/capital (no despliega)
    v_tot_mora_interes   NUMBER(18, 2); -- Mora s/Interes (DESPLIEGA : Mora s/interes )
    v_tot_mora_int_adel  NUMBER(18, 2); -- Mora interes adelantado (no desp)
    v_tot_impuesto       NUMBER(18, 2); -- Total impuesto (DESPLIEGA : ley 125/91)
    v_tot_cargo          NUMBER(18, 2); -- Total cargo (DESPLIEGA : Cargo + IVA )
    v_tot_car_cobser     NUMBER(18, 2); -- Total cargo por utilización de Cobro de Servicios
    v_tot_cargo_iva      NUMBER(18, 2); -- Total cargo IVA  (no desp)
    v_tot_int_descontado NUMBER(18, 2); -- Total interes descontado (no desp)
    v_tot_a_cobrar       NUMBER(18, 2); -- Total a cobrar (DESPLIEGA: cap+int+morai+morac+imp+cargo)
    v_tot_punitorio      NUMBER(18, 2); -- Total monto punitorio (DESPLIEGA : Punitorio)
    v_redondeo           NUMBER(3);
    v_moneda             ba_monedas.cod_moneda%type; --nr
    v_cod_moneda         VARCHAR2(1);
    v_cod_ofi_origen     pr_movimientos_his.cod_ofi_origen%TYPE;
    v_dia_mora           pr_cta_prestamos.dia_atraso%TYPE;
    v_nro_cuenta         pr_cta_prestamos.nro_cuenta%TYPE;
    v_fec_vigencia       ge_tas_fechas.fec_vigencia%TYPE;
    v_tip_valor          ge_tasas.tip_valor%TYPE;
    v_tip_tasa           ge_tasas.tipo%TYPE;
    v_cod_persona        ba_personas.cod_persona%TYPE;
    v_cod_tasa           ge_tasas.cod_tasa%TYPE;
    v_vencimiento        varchar2(8);
    v_cod_transaccion    ge_transacciones.cod_transaccion%TYPE;
    v_red_practipago     ba_cod_referencias.val_minimo%TYPE;
    v_red_infonet        ba_cod_referencias.val_minimo%TYPE;
    v_red_netel          ba_cod_referencias.val_minimo%TYPE;
    v_red_pronet         ba_cod_referencias.val_minimo%TYPE;
    v_iva_devuelto       NUMBER(18, 2) := 0; -- Iva devuelto
    r_pcpre              pr_cta_prestamos%ROWTYPE;
    v_cod_val_tasa       ge_tasas.cod_tasa%TYPE;

    v_val_tas_iva_descontado GE_TAS_FECHAS.VAL_TASA%TYPE;
    v_fec_val_vigencia       GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
    v_tip_val_valor          GE_TASAS.TIP_VALOR%TYPE;
    v_tipo                   GE_TASAS.TIPO%TYPE;
    v_cob_iva                VARCHAR2(1) := 'N';
    v_tot_iva_incluido       NUMBER(18, 2);
    v_cantidad               NUMBER(3) := 0;

    --Cursor para recuperar el nro. de cuenta, esto es, en caso que el usuario ingrese
    -- el nro. de C.I. o cuenta indistintamente como parametro, o que el cliente tenga
    --mas de un prestamo activo.
    CURSOR cta IS
      SELECT c.nro_cuenta
        FROM ba_personas a, ge_cta_clientes c, pr_cta_prestamos s
       WHERE a.cod_persona = c.cod_persona
         AND c.nro_cuenta = s.nro_cuenta
         AND c.nro_cuenta = p_nro_cuenta
         AND c.relacion = 'P'
         AND s.estado <> 'N'
         AND nvl(instr(',' || fug_obt_pardinamico('PRE_MOD_NEGADAS') || ',',
                       ',' || s.cod_modalidad || ','),
                 0) = 0;

    --Cursor para recuperar los detalles de todas las cuotas.
    CURSOR det_cuotas(v_nro_cuenta IN VARCHAR2) IS
      SELECT to_char((c.fec_vencimiento), 'ddmmyyyy') fec_vto,
             c.nro_cuota nro_cuota
        FROM pr_cuotas c
       WHERE c.nro_cuenta = v_nro_cuenta
         AND c.nro_cuota > 0
         AND c.estado <> 'N'
       ORDER BY c.nro_cuota;

    --Cursor para recuperar los detalles: la cuota mas vencida de cada cuenta.
    CURSOR cuotas(v_nro_cuenta IN VARCHAR2) IS
      SELECT to_char(MIN(c.fec_vencimiento), 'ddmmyyyy') fec_vto,
             MIN(c.nro_cuota) nro_cuota
        FROM pr_cuotas c
       WHERE c.nro_cuenta = v_nro_cuenta
         AND c.nro_cuota > 0
         AND c.estado <> 'N'
       ORDER BY c.nro_cuota;

  BEGIN
    v_fec_actual := pag_cal.fu_obt_fec_actual(3); -- fecha de hoy
    lp_ver_horario;
    v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);
    v_moneda         := it.fue_obt_mon_bcp(p_moneda); --nr
    v_can_cuotas     := 0;
    v_cod_retorno    := '000';
    v_des_retorno    := 'OK';
    IF v_cod_retorno = pag_ser.v_cod_aprobado THEN

      FOR r IN cta LOOP
        v_cantidad     := v_cantidad + 1;
        v_iva_devuelto := 0;
        v_nro_cuenta   := r.nro_cuenta;
        v_nom_titular  := fue_obt_nom_persona(fug_obt_cli_principal(v_nro_cuenta));
        pap_pre.pr_obt_dat_prestamo(v_nro_cuenta, r_ctapre);
        --
        IF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_local THEN
          v_cod_moneda := '1';
        ELSIF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_fuerte THEN
          v_cod_moneda := '2';
        ELSE
          v_cod_retorno := pag_ser.v_mon_incorrecta;
          v_des_retorno := 'Moneda incorrecta.';
        END IF;

        -- Se verifica si no tiene cobros pendientes de ser aplicados...
        DECLARE
          v_can_pag_pend NUMBER(5) := 0;
        BEGIN
          SELECT COUNT(*)
            INTO v_can_pag_pend
            FROM pr_cobros_noc
           WHERE nro_cuenta = v_nro_cuenta
             AND estado = 'I';
          IF v_can_pag_pend > 0 THEN
            v_cod_retorno := pag_ser.v_cuo_cancelada;
            v_des_retorno := 'Cuota ya pagada';
          END IF;
        END;
        --Moneda de la cuenta es la misma que eligio el usuario.
        IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
          IF nvl(fug_obt_pardinamico('PRE_OBT_PTO_COBRANZA'), 'N') = 'S' AND
             v_red_pago = 4 THEN
            FOR d IN det_cuotas(v_nro_cuenta) LOOP
              v_can_cuotas := nvl(v_can_cuotas, 0) + 1;

              pap_pre.pr_ini_autorizacion;
              pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                          v_fec_actual,
                                          d.nro_cuota,
                                          d.nro_cuota,
                                          v_cod_ofi_origen,
                                          v_mto_cobrado,
                                          v_cod_error,
                                          v_des_retorno,
                                          v_tot_capital,
                                          v_tot_interes,
                                          v_tot_int_adelantado,
                                          v_tot_mora,
                                          v_tot_mora_interes,
                                          v_tot_mora_int_adel,
                                          v_tot_punitorio,
                                          v_tot_impuesto,
                                          v_tot_cargo,
                                          v_tot_cargo_iva,
                                          v_tot_int_descontado,
                                          v_dia_mora,
                                          v_cod_tra_padre,
                                          'N'); --- cancela

              IF v_cod_error <> 0 THEN
                v_cod_retorno := pag_ser.v_err_proceso;
                v_des_retorno := 'Error en la cuenta de prestamo';
              ELSE
                v_tot_mora     := nvl(v_tot_mora, 0) +
                                  nvl(v_tot_mora_int_adel, 0) +
                                  nvl(v_tot_mora_interes, 0);
                v_tot_cargo    := nvl(v_tot_cargo, 0); -----  nvl(v_tot_cargo_iva, 0);  fm
                v_tot_a_cobrar := nvl(v_tot_capital, 0) +
                                  nvl(v_tot_interes, 0) +
                                  nvl(v_tot_mora, 0) +
                                  nvl(v_tot_impuesto, 0) +
                                  nvl(v_tot_int_adelantado, 0) +
                                  nvl(v_tot_cargo, 0) +
                                  nvl(v_tot_punitorio, 0); ---fm se agrega punitorio al total

                v_cadena := to_char(v_nro_cuenta) || ';' ||
                            to_char(d.nro_cuota) || ';' || d.fec_vto || ';' ||
                            v_tot_a_cobrar || ';'; --nr
                /*v_cadena := v_cadena || rpad(to_char(v_nro_cuenta), 15, ' ') ||
                rpad('Consulta de cuotas-1', 20, ' ') ||
                lpad(to_char(d.nro_cuota), 3, '0') ||
                lf_for_money(v_tot_capital, 16,p_cod_moneda) || lf_for_money((v_tot_interes+v_tot_int_adelantado), 16,p_cod_moneda) ||
                lf_for_money(v_tot_mora, 16,p_cod_moneda) || lf_for_money(v_tot_punitorio, 16,p_cod_moneda) ||
                lf_for_money(v_tot_cargo, 16,p_cod_moneda) || lf_for_money(v_tot_impuesto, 16,p_cod_moneda) ||
                lf_for_money(v_iva_devuelto, 16,p_cod_moneda) || lpad('0', 15, '0') || lf_for_money(v_tot_a_cobrar, 16,p_cod_moneda) ||
                v_cod_moneda || '' || d.fec_vto || '';*/ --nr
                v_vencimiento := d.fec_vto;
              END IF;
            END LOOP;
          ELSE
            FOR d IN cuotas(v_nro_cuenta) LOOP
              v_can_cuotas := nvl(v_can_cuotas, 0) + 1;

              pap_pre.pr_ini_autorizacion;
              pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                          v_fec_actual,
                                          d.nro_cuota,
                                          d.nro_cuota,
                                          v_cod_ofi_origen,
                                          v_mto_cobrado,
                                          v_cod_error,
                                          v_des_retorno,
                                          v_tot_capital,
                                          v_tot_interes,
                                          v_tot_int_adelantado,
                                          v_tot_mora,
                                          v_tot_mora_interes,
                                          v_tot_mora_int_adel,
                                          v_tot_punitorio,
                                          v_tot_impuesto,
                                          v_tot_cargo,
                                          v_tot_cargo_iva,
                                          v_tot_int_descontado,
                                          v_dia_mora,
                                          v_cod_tra_padre,
                                          'N'); --- cancela

              IF v_cod_error <> 0 THEN
                v_cod_retorno := pag_ser.v_err_proceso;
                v_des_retorno := 'Error en la cuenta de prestamo';
              ELSE
                v_tot_mora     := nvl(v_tot_mora, 0) +
                                  nvl(v_tot_mora_int_adel, 0) +
                                  nvl(v_tot_mora_interes, 0);
                v_tot_cargo    := nvl(v_tot_cargo, 0); -----  nvl(v_tot_cargo_iva, 0);  fm
                v_tot_a_cobrar := nvl(v_tot_capital, 0) +
                                  nvl(v_tot_interes, 0) +
                                  nvl(v_tot_mora, 0) +
                                  nvl(v_tot_impuesto, 0) +
                                  nvl(v_tot_int_adelantado, 0) +
                                  nvl(v_tot_cargo, 0) +
                                  nvl(v_tot_punitorio, 0); ---fm se agrega punitorio al total

                --Verificar si aplica el cobro de comisión por utilizar en la red de Pago.
                IF nvl(fug_obt_pardinamico('PRE_COM_PAGSER'), 'N') = 'S' THEN
                  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                    null,
                                                    null,
                                                    r_ctapre.cod_moneda);

                  BEGIN
                    v_cod_transaccion := fue_obt_val_max_referencia('PRE_COM_TRA_PAGSER',
                                                                    v_red_pago);
                  EXCEPTION
                    WHEN no_data_found THEN
                      v_cod_retorno := pag_ser.v_err_proceso;
                      v_des_retorno := 'Error en el proceso';
                  END;

                  pag_gen.pr_obt_val_tasa(r_ctapre.cod_modulo,
                                          r_ctapre.cod_modalidad,
                                          r_ctapre.cod_oficina,
                                          v_nro_cuenta,
                                          r_ctapre.cod_moneda,
                                          v_tot_a_cobrar,
                                          'N',
                                          v_cod_tasa,
                                          v_cod_transaccion,
                                          sysdate,
                                          v_tot_car_cobser,
                                          v_fec_vigencia,
                                          v_tip_valor,
                                          v_tip_tasa,
                                          v_cod_persona);

                  BEGIN
                    select val_minimo
                      into v_red_pronet
                      from ba_cod_referencias
                     where dominio = 'PRE_COM_TRA_PAGSER'
                       and significado = 'PRONET';
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      v_red_pronet := 0;
                  END;

                  BEGIN
                    select val_minimo
                      into v_red_practipago
                      from ba_cod_referencias
                     where dominio = 'PRE_COM_TRA_PAGSER'
                       and significado = 'PRACTIPAGO';
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      v_red_practipago := 0;
                  END;

                  -- INFONET --
                  BEGIN
                    select val_minimo
                      into v_red_infonet
                      from ba_cod_referencias
                     where dominio = 'PRE_COM_TRA_PAGSER'
                       and significado = 'INFONET';
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      v_red_infonet := 0;
                  END;

                  -- NETEL --
                  BEGIN
                    select val_minimo
                      into v_red_netel
                      from ba_cod_referencias
                     where dominio = 'PRE_COM_TRA_PAGSER'
                       and significado = 'NETEL';
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      v_red_netel := 0;
                  END;

                  IF v_red_practipago = v_red_pago THEN
                    IF fug_obt_pardinamico('PRE_ULT_TRA_PRACTIPAGO') is not null THEN
                      if v_tot_a_cobrar >=
                         fug_obt_pardinamico('PRE_ULT_TRA_PRACTIPAGO') THEN
                        v_cod_tasa := null;
                        pag_gen.pr_obt_val_tasa(r_ctapre.cod_modulo,
                                                r_ctapre.cod_modalidad,
                                                r_ctapre.cod_oficina,
                                                v_nro_cuenta,
                                                r_ctapre.cod_moneda,
                                                v_tot_a_cobrar,
                                                'N',
                                                v_cod_tasa,
                                                v_cod_transaccion,
                                                sysdate,
                                                v_tot_car_cobser,
                                                v_fec_vigencia,
                                                v_tip_valor,
                                                v_tip_tasa,
                                                v_cod_persona);

                        v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                                 0) *
                                                                           nvl(v_tot_car_cobser,
                                                                                 0)) / 100)),
                                                  v_redondeo);
                      else
                        --sino, toma la tasa por rangos.
                        v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
                      end if;

                    ELSE
                      -- calculo para ACI
                      --se analiza comision total calculada con respecto a valor en parametros
                      v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                               0) *
                                                                         nvl(v_tot_car_cobser,
                                                                               0)) / 100)),
                                                v_redondeo);
                      if fug_obt_pardinamico('PRE_MTO_SUP_PRACTIPAGO') is not null and
                         fug_obt_pardinamico('PRE_MTO_INF_PRACTIPAGO') is not null THEN
                        if v_tot_car_cobser <
                           fug_obt_pardinamico('PRE_MTO_INF_PRACTIPAGO') THEN
                          v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_PRACTIPAGO');
                          v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                        elsif v_tot_car_cobser >
                              fug_obt_pardinamico('PRE_MTO_SUP_PRACTIPAGO') THEN
                          v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_PRACTIPAGO');
                          v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                        else
                          v_tot_car_cobser := round(v_tot_car_cobser / 1.1);
                        end if;
                      end if;

                      v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
                    END IF;
                  ELSIF v_red_infonet = v_red_pago THEN
                    --se analiza comision total calculada con respecto a valor en parametros
                    v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                             0) *
                                                                       nvl(v_tot_car_cobser,
                                                                             0)) / 100)),
                                              v_redondeo);
                    if fug_obt_pardinamico('PRE_MTO_SUP_INFONET') is not null and
                       fug_obt_pardinamico('PRE_MTO_INF_INFONET') is not null THEN
                      if v_tot_car_cobser <
                         fug_obt_pardinamico('PRE_MTO_INF_INFONET') THEN
                        v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_INFONET');
                        v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                      elsif v_tot_car_cobser >
                            fug_obt_pardinamico('PRE_MTO_SUP_INFONET') THEN
                        v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_INFONET');
                        v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                      else
                        v_tot_car_cobser := round(v_tot_car_cobser / 1.1);
                      end if;
                    end if;

                    v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
                  ELSIF v_red_pronet = v_red_pago THEN
                    --se analiza monto total cobrado con respecto a valor en parametros
                    IF fug_obt_pardinamico('PRE_ULT_TRA_PRONET') is not null and
                       fug_obt_pardinamico('PRE_PRI_TRA_PRONET') is not null THEN
                      if v_tot_a_cobrar <=
                         fug_obt_pardinamico('PRE_ULT_TRA_PRONET') and
                         v_tot_a_cobrar >
                         fug_obt_pardinamico('PRE_PRI_TRA_PRONET') THEN
                        v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                                 0) *
                                                                           nvl(v_tot_car_cobser,
                                                                                 0)) / 100)),
                                                  v_redondeo);
                      else
                        v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
                      end if;
                    ELSE
                      --se analiza comision total calculada con respecto a valor en parametros
                      v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                               0) *
                                                                         nvl(v_tot_car_cobser,
                                                                               0)) / 100)),
                                                v_redondeo);
                      if fug_obt_pardinamico('PRE_MTO_SUP_PRONET') is not null and
                         fug_obt_pardinamico('PRE_MTO_INF_PRONET') is not null THEN
                        if v_tot_car_cobser <
                           fug_obt_pardinamico('PRE_MTO_INF_PRONET') THEN
                          v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_PRONET');
                          v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                        elsif v_tot_car_cobser >
                              fug_obt_pardinamico('PRE_MTO_SUP_PRONET') THEN
                          v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_PRONET');
                          v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                        else
                          v_tot_car_cobser := round(v_tot_car_cobser / 1.1);
                        end if;
                      end if;
                      v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
                    END IF;
                  ELSIF v_red_netel = v_red_pago THEN
                    --se analiza comision total calculada con respecto a valor en parametros
                    v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                             0) *
                                                                       nvl(v_tot_car_cobser,
                                                                             0)) / 100)),
                                              v_redondeo);
                    if fug_obt_pardinamico('PRE_MTO_SUP_NETEL') is not null and
                       fug_obt_pardinamico('PRE_MTO_INF_NETEL') is not null THEN
                      if v_tot_car_cobser <
                         fug_obt_pardinamico('PRE_MTO_INF_NETEL') THEN
                        v_tot_car_cobser   := fug_obt_pardinamico('PRE_MTO_INF_NETEL');
                        v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_NETEL');
                        v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);

                      elsif v_tot_car_cobser >
                            fug_obt_pardinamico('PRE_MTO_SUP_NETEL') THEN
                        v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_NETEL');
                        v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                      else
                        v_tot_car_cobser := round(v_tot_car_cobser / 1.1);
                      end if;
                    end if;

                    v_tot_car_cobser := nvl(v_tot_car_cobser, 0);

                  ELSE
                    v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                             0) *
                                                                       nvl(v_tot_car_cobser,
                                                                             0)) / 100)),
                                              v_redondeo);
                  END IF;

                  INSERT INTO pr_cta_gastos
                    (nro_cuenta,
                     cod_transaccion,
                     cod_moneda,
                     monto,
                     fec_ingreso,
                     fec_vencimiento,
                     fec_ini_vigencia,
                     cod_modulo,
                     cod_modalidad,
                     nro_solicitud,
                     hor_ult_pago)
                  VALUES
                    (v_nro_cuenta,
                     v_cod_transaccion,
                     r_ctapre.cod_moneda,
                     v_tot_car_cobser,
                     v_fec_actual,
                     r_ctapre.fec_vencimiento,
                     r_ctapre.fec_inicio,
                     r_ctapre.cod_modulo,
                     r_ctapre.cod_modalidad,
                     r_ctapre.nro_solicitud,
                     v_hor_actual);
                  v_tot_a_cobrar := 0; --se cera para obtener deuda con la comisión más los cargos en caso de préstamos con atrasos
                  --Se vuelve a consultar el préstamo para obtener el cargo, calculado con su impuesto.
                  pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                              v_fec_actual,
                                              d.nro_cuota,
                                              d.nro_cuota,
                                              v_cod_ofi_origen,
                                              v_mto_cobrado,
                                              v_cod_error,
                                              v_des_retorno,
                                              v_tot_capital,
                                              v_tot_interes,
                                              v_tot_int_adelantado,
                                              v_tot_mora,
                                              v_tot_mora_interes,
                                              v_tot_mora_int_adel,
                                              v_tot_punitorio,
                                              v_tot_impuesto,
                                              v_tot_cargo,
                                              v_tot_cargo_iva,
                                              v_tot_int_descontado,
                                              v_dia_mora,
                                              v_cod_tra_padre,
                                              'N');

                  v_tot_mora     := nvl(v_tot_mora, 0) +
                                    nvl(v_tot_mora_int_adel, 0) +
                                    nvl(v_tot_mora_interes, 0);
                  v_tot_cargo    := nvl(v_tot_cargo, 0);
                  v_tot_a_cobrar := nvl(v_tot_capital, 0) +
                                    nvl(v_tot_interes, 0) +
                                    nvl(v_tot_mora, 0) +
                                    nvl(v_tot_impuesto, 0) +
                                    nvl(v_tot_int_adelantado, 0) +
                                    nvl(v_tot_cargo, 0) +
                                    nvl(v_tot_punitorio, 0);

                  delete pr_cta_gastos
                   where nro_cuenta = v_nro_cuenta
                     and cod_transaccion = v_cod_transaccion
                     and fec_ingreso = v_fec_actual
                     and hor_ult_pago = v_hor_actual;
                END IF;
                v_cadena := to_char(v_nro_cuenta) || ';' ||
                            to_char(d.nro_cuota) || ';' || d.fec_vto || ';' ||
                            v_tot_a_cobrar || ';'; --nr
                /*v_cadena := v_cadena || rpad(to_char(v_nro_cuenta), 15, ' ') ||
                rpad('Consulta de cuotas-2', 20, ' ') ||
                lpad(to_char(d.nro_cuota), 3, '0') ||
                lf_for_money(v_tot_capital, 16,p_cod_moneda) || lf_for_money((v_tot_interes+v_tot_int_adelantado), 16,p_cod_moneda) ||
                lf_for_money(v_tot_mora, 16,p_cod_moneda) || lf_for_money(v_tot_punitorio, 16,p_cod_moneda) ||
                lf_for_money(v_tot_cargo, 16,p_cod_moneda) || lf_for_money(v_tot_impuesto, 16,p_cod_moneda) ||
                lf_for_money(v_iva_devuelto, 16,p_cod_moneda) || lpad('0', 15, '0') ||  lf_for_money(v_tot_a_cobrar, 16,p_cod_moneda) ||
                v_cod_moneda || '' || d.fec_vto || '';*/ --nr
                v_vencimiento := d.fec_vto;
              END IF;
            END LOOP;
          END IF;
          --Consulta para obtener valor de cancelación.
          pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                      v_fec_actual,
                                      0,
                                      999,
                                      v_cod_ofi_origen,
                                      v_mto_cobrado,
                                      v_cod_error,
                                      v_des_retorno,
                                      v_tot_capital,
                                      v_tot_interes,
                                      v_tot_int_adelantado,
                                      v_tot_mora,
                                      v_tot_mora_interes,
                                      v_tot_mora_int_adel,
                                      v_tot_punitorio,
                                      v_tot_impuesto,
                                      v_tot_cargo,
                                      v_tot_cargo_iva,
                                      v_tot_int_descontado,
                                      v_dia_mora,
                                      359,
                                      'T');

          v_tot_a_cobrar := nvl(v_tot_capital, 0) + nvl(v_tot_interes, 0) +
                            nvl(v_tot_mora, 0) + nvl(v_tot_mora_interes, 0) +
                            nvl(v_tot_impuesto, 0) +
                            nvl(v_tot_int_adelantado, 0) +
                            nvl(v_tot_cargo, 0) + nvl(v_tot_punitorio, 0) +
                            nvl(v_tot_mora_int_adel, 0);

          --Obtener valor final para cancelación, con la comisión si aplica
          IF nvl(fug_obt_pardinamico('PRE_COM_PAGSER'), 'N') = 'S' AND
             v_red_pago != 4 THEN
            v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                              null,
                                              null,
                                              r_ctapre.cod_moneda);
            BEGIN
              v_cod_transaccion := fue_obt_val_max_referencia('PRE_COM_TRA_PAGSER',
                                                              v_red_pago);
            EXCEPTION
              WHEN no_data_found THEN
                v_cod_retorno := pag_ser.v_err_proceso;
                v_des_retorno := 'Error en el proceso';
            END;

            pag_gen.pr_obt_val_tasa(r_ctapre.cod_modulo,
                                    r_ctapre.cod_modalidad,
                                    r_ctapre.cod_oficina,
                                    v_nro_cuenta,
                                    r_ctapre.cod_moneda,
                                    v_tot_a_cobrar,
                                    'N',
                                    v_cod_tasa,
                                    v_cod_transaccion,
                                    sysdate,
                                    v_tot_car_cobser,
                                    v_fec_vigencia,
                                    v_tip_valor,
                                    v_tip_tasa,
                                    v_cod_persona);

            IF v_red_practipago = v_red_pago THEN
              IF fug_obt_pardinamico('PRE_ULT_TRA_PRACTIPAGO') is not null THEN
                if v_tot_a_cobrar >=
                   fug_obt_pardinamico('PRE_ULT_TRA_PRACTIPAGO') THEN
                  --Si es mayor, aplica porcentaje
                  v_cod_tasa := null;
                  pag_gen.pr_obt_val_tasa(r_ctapre.cod_modulo,
                                          r_ctapre.cod_modalidad,
                                          r_ctapre.cod_oficina,
                                          v_nro_cuenta,
                                          r_ctapre.cod_moneda,
                                          v_tot_a_cobrar,
                                          'N',
                                          v_cod_tasa,
                                          v_cod_transaccion,
                                          sysdate,
                                          v_tot_car_cobser,
                                          v_fec_vigencia,
                                          v_tip_valor,
                                          v_tip_tasa,
                                          v_cod_persona);

                  v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                           0) *
                                                                     nvl(v_tot_car_cobser,
                                                                           0)) / 100)),
                                            v_redondeo);
                else
                  --sino, toma la tasa por rangos.
                  v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
                end if;
              ELSE
                v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
              END IF;
            ELSIF v_red_infonet = v_red_pago THEN
              v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                       0) *
                                                                 nvl(v_tot_car_cobser,
                                                                       0)) / 100)),
                                        v_redondeo);
              if fug_obt_pardinamico('PRE_MTO_SUP_INFONET') is not null and
                 fug_obt_pardinamico('PRE_MTO_INF_INFONET') is not null THEN
                if v_tot_car_cobser <
                   fug_obt_pardinamico('PRE_MTO_INF_INFONET') THEN
                  v_tot_car_cobser := fug_obt_pardinamico('PRE_MTO_INF_INFONET');
                elsif v_tot_car_cobser >
                      fug_obt_pardinamico('PRE_MTO_SUP_INFONET') THEN
                  v_tot_car_cobser := fug_obt_pardinamico('PRE_MTO_SUP_INFONET');
                end if;
              end if;

              v_tot_car_cobser := nvl(v_tot_car_cobser, 0);

            ELSIF v_red_pronet = v_red_pago THEN
              --se analiza monto total cobrado con respecto a valor en parametros
              IF fug_obt_pardinamico('PRE_ULT_TRA_PRONET') is not null and
                 fug_obt_pardinamico('PRE_PRI_TRA_PRONET') is not null THEN
                if v_tot_a_cobrar <=
                   fug_obt_pardinamico('PRE_ULT_TRA_PRONET') and
                   v_tot_a_cobrar >
                   fug_obt_pardinamico('PRE_PRI_TRA_PRONET') THEN
                  v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                           0) *
                                                                     nvl(v_tot_car_cobser,
                                                                           0)) / 100)),
                                            v_redondeo);
                else
                  v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
                end if;
              ELSE
                --se analiza comision total calculada con respecto a valor en parametros
                v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                         0) *
                                                                   nvl(v_tot_car_cobser,
                                                                         0)) / 100)),
                                          v_redondeo);
                if fug_obt_pardinamico('PRE_MTO_SUP_PRONET') is not null and
                   fug_obt_pardinamico('PRE_MTO_INF_PRONET') is not null THEN
                  if v_tot_car_cobser <
                     fug_obt_pardinamico('PRE_MTO_INF_PRONET') THEN
                    v_tot_car_cobser := fug_obt_pardinamico('PRE_MTO_INF_PRONET');
                  elsif v_tot_car_cobser >
                        fug_obt_pardinamico('PRE_MTO_SUP_PRONET') THEN
                    v_tot_car_cobser := fug_obt_pardinamico('PRE_MTO_SUP_PRONET');
                  end if;
                end if;

                v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
              END IF;
            ELSIF v_red_netel = v_red_pago THEN
              --se analiza comision total calculada con respecto a valor en parametros
              v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                       0) *
                                                                 nvl(v_tot_car_cobser,
                                                                       0)) / 100)),
                                        v_redondeo);
              if fug_obt_pardinamico('PRE_MTO_SUP_NETEL') is not null and
                 fug_obt_pardinamico('PRE_MTO_INF_NETEL') is not null THEN
                if v_tot_car_cobser <
                   fug_obt_pardinamico('PRE_MTO_INF_NETEL') THEN
                  v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_NETEL');
                  v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);

                elsif v_tot_car_cobser >
                      fug_obt_pardinamico('PRE_MTO_SUP_NETEL') THEN
                  v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_NETEL');
                  v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                end if;
              end if;

              v_tot_car_cobser := nvl(v_tot_car_cobser, 0);

            ELSE
              v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                       0) *
                                                                 nvl(v_tot_car_cobser,
                                                                       0)) / 100)),
                                        v_redondeo);
            END IF;

            INSERT INTO pr_cta_gastos
              (nro_cuenta,
               cod_transaccion,
               cod_moneda,
               monto,
               fec_ingreso,
               fec_vencimiento,
               fec_ini_vigencia,
               cod_modulo,
               cod_modalidad,
               nro_solicitud,
               hor_ult_pago)
            VALUES
              (v_nro_cuenta,
               v_cod_transaccion,
               r_ctapre.cod_moneda,
               v_tot_car_cobser,
               v_fec_actual,
               r_ctapre.fec_vencimiento,
               r_ctapre.fec_inicio,
               r_ctapre.cod_modulo,
               r_ctapre.cod_modalidad,
               r_ctapre.nro_solicitud,
               v_hor_actual);
            v_tot_a_cobrar := 0; --se cera para obtener deuda con la comisión más los cargos en caso de préstamos con atrasos
            --Se vuelve a consultar el préstamo para obtener el cargo, calculado con su impuesto.
            pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                        v_fec_actual,
                                        0,
                                        999,
                                        v_cod_ofi_origen,
                                        v_mto_cobrado,
                                        v_cod_error,
                                        v_des_retorno,
                                        v_tot_capital,
                                        v_tot_interes,
                                        v_tot_int_adelantado,
                                        v_tot_mora,
                                        v_tot_mora_interes,
                                        v_tot_mora_int_adel,
                                        v_tot_punitorio,
                                        v_tot_impuesto,
                                        v_tot_cargo,
                                        v_tot_cargo_iva,
                                        v_tot_int_descontado,
                                        v_dia_mora,
                                        359,
                                        'T');

            delete pr_cta_gastos
             where nro_cuenta = v_nro_cuenta
               and cod_transaccion = v_cod_transaccion
               and fec_ingreso = v_fec_actual
               and hor_ult_pago = v_hor_actual;
          END IF;

          --calcula el iva devuelto
          --- Inicializar variables de cobro
          --pap_pre.pr_ini_var_cobro;
          pap_pre.pr_obt_dat_prestamo(v_nro_cuenta, r_pcpre);
          pag_gen.pr_obt_val_tasa(6,
                                  r_pcpre.cod_modalidad,
                                  r_pcpre.cod_oficina,
                                  v_nro_cuenta,
                                  r_pcpre.cod_moneda,
                                  v_tot_int_descontado,
                                  'N',
                                  v_cod_val_tasa,
                                  1708,
                                  v_fec_actual,
                                  v_val_tas_iva_descontado,
                                  v_fec_val_vigencia,
                                  v_tip_val_valor,
                                  v_tipo);

          --verificar redondeo
          v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                            6,
                                            r_pcpre.cod_modalidad,
                                            r_pcpre.cod_moneda);

          IF fug_obt_pardinamico('PRE_IVA_INT_DESCONTADO') = 'S' THEN
            -- Verificar si se cobro iva en la solicitud
            BEGIN
              SELECT 'S'
                INTO v_cob_iva
                FROM pr_sol_cargos
               WHERE nro_solicitud = r_pcpre.nro_solicitud
                 AND cod_transaccion = 709;
            EXCEPTION
              WHEN others THEN
                v_cob_iva := 'N';
            END;
            IF v_cob_iva = 'S' then
              v_iva_devuelto := round(nvl(v_tot_int_descontado, 0) *
                                      (v_val_tas_iva_descontado / 100),
                                      v_redondeo);
            ELSE
              v_iva_devuelto := 0;
            END IF;
          ELSE
            v_iva_devuelto := 0;
          END IF;

          v_tot_moratorio := nvl(v_tot_mora, 0) +
                             nvl(v_tot_mora_int_adel, 0) +
                             nvl(v_tot_mora_interes, 0);
          v_tot_cargo     := nvl(v_tot_cargo, 0);
          v_tot_a_cobrar  := nvl(v_tot_capital, 0) + nvl(v_tot_interes, 0) +
                             nvl(v_tot_moratorio, 0) +
                             nvl(v_tot_impuesto, 0) +
                             nvl(v_tot_int_adelantado, 0) +
                             nvl(v_tot_cargo, 0) + nvl(v_tot_punitorio, 0) -
                             nvl(v_iva_devuelto, 0);

          v_can_cuotas := nvl(v_can_cuotas, 0) + 1;
          -- v_cadena :=  to_char(v_nro_cuenta)||';'||v_vencimiento||';'||v_tot_a_cobrar||';'; --nr
          /*v_cadena := v_cadena || rpad(to_char(v_nro_cuenta), 15, ' ') ||
          rpad('Cancelación Cuenta', 20, ' ') ||
          lpad(to_char(0), 3, '0') ||
          lf_for_money(v_tot_capital, 16,p_cod_moneda) || lf_for_money((v_tot_interes+v_tot_int_adelantado), 16,p_cod_moneda) ||
          lf_for_money(v_tot_moratorio, 16,p_cod_moneda) || lf_for_money(v_tot_punitorio, 16,p_cod_moneda) ||
          lf_for_money(v_tot_cargo, 16,p_cod_moneda) || lf_for_money(v_tot_impuesto, 16,p_cod_moneda) ||
          lf_for_money(v_iva_devuelto, 16,p_cod_moneda) || lpad('0', 15, '0') ||
          lf_for_money(v_tot_a_cobrar, 16,p_cod_moneda) ||
          v_cod_moneda || '' || v_vencimiento || '';*/ --nr --en que caso se utiliza esta cadena?
        END IF;
        EXIT WHEN v_cantidad = 10;
      END LOOP;
      IF v_nro_cuenta IS NULL THEN
        --No encontró la cuenta, emite mensaje de error.
        v_cod_retorno := pag_ser.v_cta_incorrecta;
        v_des_retorno := 'Cuenta o doc. inexistente';
      END IF;

      --Se arma string de la cabecera.
      /*v_cad_cabecera := rpad(p_cod_servicio, 5, ' ') || lpad(p_tip_transaccion, 2, '0') ||
                        rpad(v_cod_retorno, 3, ' ') || rpad(v_des_retorno, 30, ' ') ||
                        rpad(v_nom_titular, 60, ' ') || lpad(to_char(v_can_cuotas), 3, '0');
      v_cadena       := v_cad_cabecera || v_cadena;*/ --nr
    ELSE
      v_cadena :=  --rpad(p_cod_servicio, 5, ' ') || lpad(p_tip_transaccion, 2, '0') || nr
       rpad(v_cod_retorno, 3, ' ') ||
                  rpad(v_des_retorno, 30, ' ') ||
                  rpad(v_nom_titular, 60, ' ') ||
                  lpad(to_char(v_can_cuotas), 3, '0');
    END IF;
    commit;
    RETURN v_cadena;
  END fu_obt_deu_prestamo;

/*Funcion que verifica si ya se procesaron cobros del servicio para la oficina*/
FUNCTION fu_ver_cob_procesados
(p_cod_servicio IN  GE_COB_SER_PARAMETROS.COD_SERVICIO%TYPE,
 p_cod_usuario in ge_cob_servicios.cod_usuario%type,
 p_fecha in ge_cob_servicios.fecha%type,
 p_cod_oficina ge_cob_servicios.cod_ofi_origen%type )
RETURN BOOLEAN
is
v_existe number := 0;
begin
   --ver si ya se proceso el cobro para la oficina
   select nvl(count(*),0)
     into v_existe
     from ge_cob_servicios
    where tip_cobro ='A'
      and estado = 'P'
      and fecha = p_fecha
      and cod_servicio = p_cod_servicio
      and cod_ofi_origen = p_cod_oficina;
   if v_existe > 0 then
      --verificar si hay con error para reprocesar
      select nvl(count(*),0)
        into v_existe
        from ge_cob_servicios
       where tip_cobro ='A'
         and estado = 'E'
         and fecha = p_fecha
         and cod_servicio = p_cod_servicio
         and cod_ofi_origen = p_cod_oficina;
      if v_existe > 0 then
        return false;
      else
        return true;
      end if;
   else
      return false;
   end if;
exception
   when others then
      raise_application_error(-20403,'Recup.Cobros Procesados. '||sqlerrm);
end;
/* funcion que verifica si la referencia es numerico de 15 para poder grabar en los movimientos */
FUNCTION fu_ver_es_numerico
(p_referencia in ge_cob_servicios.referencia1%type,
 p_formato IN GE_COB_SER_PARAMETROS.FOR_CAMPO1%TYPE)
return boolean is
 v_formato VARCHAR2(1);
 v_letra   VARCHAR2(1);
 verror    EXCEPTION;
-- v_abc     VARCHAR2(30) := 'ABDECFGHIJKLMNOPQRSTUVWXYZ';
 v_num     VARCHAR2(10) := '0123456789';
 v_long    NUMBER(3) := 15;
 v_fecha   DATE;
 v_ref     VARCHAR2(20);

begin
   v_ref := ltrim( p_referencia );
   --- verifico el formato y la longitud del campo ---
   IF length(v_ref) > v_long THEN
      --supera la longitud del campo
      return false;
   END IF;
   FOR I IN 1..v_long LOOP
      v_formato := substr( p_formato, I, 1 );--p_formato debe ser 9999...
      v_letra   := substr( v_ref, I, 1 );
      IF v_formato = '9' THEN
         --si el formato no tiene 9 no es numerico
         IF v_letra IS NOT NULL AND instr( v_num, v_letra ) = 0 THEN
          return false;
         END IF;
      ELSIF v_letra <> v_formato THEN
         return false;
      END IF;
   END LOOP;
   return true;
end;

/* OMM 24/01/2011 Agregado para realizar reversiones de pagos. */

FUNCTION fu_aut_pago
                    (p_sesion in varchar2,
                     p_servicio IN number,
                     p_cuenta in varchar2,
                     p_fecha in varchar2,
                     p_hora in varchar2,
                     p_nro_tran varchar2,
                     p_nro_lote varchar2,
                     p_nro_ip varchar2,
                     p_terminal varchar2,
                     p_moneda number,
                     p_imp_tran number,
                     p_imp_comision number,
                     p_imp_mora number,
                     p_imp_interes number)
return varchar2 is
 v_nro_cuenta       ge_movimientos.nro_cuenta%type;
 v_cod_tra_padre    ge_movimientos.cod_tra_padre%type;
 v_cod_ofi_origen   ge_movimientos.cod_oficina%type;
 v_cod_mod_padre    ge_movimientos.cod_modulo%type;
 v_cod_mad_padre    ge_movimientos.cod_modalidad%type ;
 v_sal_disponible   ge_movimientos.monto%type;
 v_nro_operacion    ge_movimientos.nro_documento%type;
 v_monto            ge_movimientos.monto%type;
 v_cod_transaccion  ge_transacciones.cod_transaccion%type;
 v_nro_cta_credito  ge_movimientos.nro_cuenta%type;
 v_nvo_estado varchar2(1);
 --v_msj_respuesta varchar2(250);
 --v_cod_respuesta number(2);
 v_procesa varchar2(1);
 v_ret     NUMBER(3);
 v_cod_res          varchar2(2); -- para limite global de operaciones

 -- Procedimiento para actualizar la cantidad de pago para la sesión DDSI-422
 PROCEDURE pr_upd_sesiones(p_sesion IN varchar2,
                           p_nro_cuenta IN varchar2,
                            p_nro_ip IN varchar2) IS
 PRAGMA AUTONOMOUS_TRANSACTION;
 BEGIN
      update bw_sesiones
         set can_operaciones = can_operaciones + 1
      where nro_sesion = p_sesion
         and nro_cuenta = p_nro_cuenta
         and nro_ip = p_nro_ip;
      commit;
 EXCEPTION
      WHEN OTHERS THEN
         NULL;
 END;

begin
 v_cod_respuesta := 0;
 v_msj_respuesta := '';
 v_nro_cuenta := p_cuenta;
 v_cod_transaccion := 503;--débito en caja de ahorros
 v_cod_tra_padre := 485;
 v_cod_mod_padre := 9;
 v_cod_mad_padre := 91;
 -- OMM 11/02/2011 Para poder asignar otra cuenta.
 v_nro_cta_credito := fug_obt_pardinamico('NRO_CTA_CRE_SERVICIOS');
 v_cod_ofi_origen := 31 ; -- Oficina origen para realizar interoficinas
 v_monto := nvl(p_imp_tran,0);
 v_nro_operacion := substr(p_nro_tran,1,15);
/********/

 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

 if lf_val_sesion(p_sesion,p_nro_ip, v_nro_cuenta)= 'N' then
        v_cod_respuesta := -1;
        v_msj_respuesta := 'Sesión Inexistente';
   raise fin_por_error;
 end if;
 -- Obtiene datos de la cuenta débito
 pag_cta.pr_obt_cuenta(v_nro_cuenta);
 if pag_cta.fu_obt_cod_error() <> 0 then
    v_cod_respuesta := -1;
    v_msj_respuesta := 'Cuenta Débito '|| v_nro_cuenta||' inexistente.';
    raise fin_por_error;
 end if;

 -- OMM 24/01/2011 En BBVA solo se paga con Cuentas en moneda GS
 if pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,v_cod_transaccion, pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad) = 'S' then
    v_cod_respuesta := -1;
    v_msj_respuesta := 'Transaccion '||pag_cta.g_ctas.cod_modulo||'-'||pag_cta.g_ctas.cod_modalidad||'-'||v_cod_transaccion||' prohibida para la Cta. '||v_nro_cuenta;
    raise fin_por_error;
 else
 /* OMM 25/01/2011 Se modifico para tener en cuenta el modulo y modalidad de la cuenta */
    pag_cta.pr_ver_operacion(v_nro_cuenta,v_cod_tra_padre, v_cod_mod_padre, v_cod_mad_padre,
                             'D', pag_cta.g_ctas.cod_moneda, v_monto, v_cod_ofi_origen, pag_cta.g_ctas.cod_modulo,
                             pag_cta.g_ctas.cod_modalidad, v_nvo_estado, v_sal_disponible, v_procesa, v_cod_transaccion);

    if v_procesa = 'N' then
       -- no se puede debitar
       if instr(upper(pag_cta.G_MSJ_ERROR),'INSUFIC') > 0 then
          -- saldo insuficiente
          v_cod_respuesta := -1;
          v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;
          raise fin_por_error;
       else
          v_cod_respuesta := -1;
          v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;
          raise fin_por_error;
       end if;
    else

       lp_ver_horario;

       -- se controla la transacción
       if lf_ver_transaccion(v_nro_cuenta, v_monto, p_servicio) = 'S' then
         v_cod_respuesta := -1;
         v_msj_respuesta := 'Favor aguarde 10 minutos para ingresar la misma transacción';
       end if;

       -- 07/05/2012 : se agrega control de limite
       if v_cod_respuesta <> -1 then
          v_cod_res := paw_bce.fu_obt_limite('082',
             null, -- cod_persona se saca de bw_sessiones
             v_nro_cuenta,
             pag_cta.g_ctas.cod_moneda,
             503,
             v_cod_tra_padre,
             v_monto,
             'C',
             null, -- no importa el ente
             p_sesion,
             p_nro_ip);
       end if;

       if v_cod_res in ('-2', '-1') then
          v_cod_respuesta := -2;
          v_msj_respuesta := 'El límite operativo no existe o ha sido sobrepasado';
       end if;
       -- fin limite operativo

       if v_cod_respuesta <> -1 and v_cod_respuesta <> -2 then
          -- se puede registrar
          pag_cta.PR_SET_VARIABLES(v_cod_usuario, v_fec_valor,
                                    v_cod_tra_padre, 'N', 'N',
                                    v_nro_secuencia, null,
                                    v_cod_ofi_origen, v_cod_mod_padre, v_cod_mad_padre);

          v_nro_secuencia         := v_nro_secuencia + 1;

          pag_cta.PR_ACT_OPERACION(v_nro_cuenta, v_hor_actual,'D',
                                   pag_cta.g_ctas.cod_moneda, v_monto, v_cod_tra_padre,
                                   v_cod_transaccion, v_nro_operacion, null,
                                   v_cod_ofi_origen, v_cod_mod_padre, v_cod_mad_padre,
                                   null, null,
                                   'Cta:' ||v_nro_cuenta||'-'||
                                   'Lote:'||p_nro_lote  ||'-'||
                                   'Tran:'||to_number(v_nro_operacion)||'-'||
                                   'DB Pag.Serv:'||p_servicio ||' via HB',
                                   'N', v_nro_secuencia, v_fec_valor,
                                   null, null, null);

          -- Obtiene datos de la cuenta débito
          pag_cta.pr_obt_cuenta(v_nro_cta_credito);
          if pag_cta.fu_obt_cod_error() <> 0 then
             v_cod_respuesta := -1;
             v_msj_respuesta := 'Cuenta Crédito '|| v_nro_cta_credito ||' inexistente.';
             raise fin_por_error;
          end if;

          if v_cod_respuesta <> -1 then
             -- Inserto movimiento para crédito cuenta contable
             -- Aumento la secuencia
             v_nro_secuencia         := v_nro_secuencia + 1;
             pag_cta.PR_ACT_OPERACION(v_nro_cta_credito, v_hor_actual,'C',
                                      pag_cta.g_ctas.cod_moneda, v_monto, v_cod_tra_padre,
                                      602, v_nro_operacion, null,
                                      v_cod_ofi_origen, v_cod_mod_padre, v_cod_mad_padre,
                                      null, null,
                                      'Cta:' ||v_nro_cuenta ||'-'||
                                      'Lote:'||p_nro_lote   ||'-'||
                                      'Tran:'||to_number(v_nro_operacion)||'-'||
                                      'CR Pag.Serv:'||p_servicio ||' via HB',
                                      'N', v_nro_secuencia, v_fec_valor,
                                      null, null, null);

             insert into bw_pag_servicios(nro_cuenta,cod_servicio,fecha, hora,nro_transaccion,
                                         nro_lote,ip_usuario,terminal,cod_moneda,mto_transaccion,mto_comision,
                                         mto_mora,mto_interes,reversado,mto_debito,cod_mon_servicio, nro_sesion)
                                  values(v_nro_cuenta,p_servicio,v_fec_actual,v_hor_actual,p_nro_tran,
                                         p_nro_lote, p_nro_ip,p_terminal,pag_gen.fu_obt_mon_local,p_imp_tran, p_imp_comision,
                                         p_imp_mora, p_imp_interes,'N',v_monto,p_moneda, p_sesion);

         BEGIN
            v_ret:=PAW_not.fu_not_pag_servicios(v_nro_cuenta, v_monto, p_moneda, 'P', SYSDATE);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
             -- se actualiza la cantidad de pago para la sesión
             pr_upd_sesiones(p_sesion, v_nro_cuenta, p_nro_ip);
           end if ;

           if nvl(pag_cta.g_cod_error,0)<> 0 then
              -- hubo error en el registro del debito o credito
              v_cod_respuesta := -1;
              v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;
              raise fin_por_error;
           end if;

       end if;

    end if;

 end if;



/********/
    if v_cod_respuesta = 0 then
       return '0~OK~'||v_fec_valor||'~'||v_hor_actual;
    else
       raise fin_por_error;
    end if;

  exception
    when fin_por_error then
         return v_cod_respuesta||'~'||v_msj_respuesta||'~'||v_fec_valor||'~'||v_hor_actual;
    when others then
         return 'Ha ocurrido un error no manejado, intente nuevamente más tarde.';
         /*ver de tener una tabla de errores o enviar los mismos por mail*/
end;

  FUNCTION fu_cob_prestamo(p_nro_cuenta IN pr_cuotas.nro_cuenta%TYPE,
                           p_nro_cuota  IN pr_cuotas.nro_cuota%TYPE,
                           p_importe    IN pr_cuotas.mto_capital%TYPE,
                           p_cod_moneda IN NUMBER,
                           --p_cod_moneda      IN pr_cta_prestamos.cod_moneda%TYPE, --se comenta porque llega como 6900 nr
                           p_tip_pago        IN VARCHAR2,
                           p_nro_cheque      IN VARCHAR2,
                           p_cod_banco       IN VARCHAR2,
                           p_fec_cheque      IN DATE,
                           p_tip_transaccion IN bw_pag_servicios.nro_transaccion%TYPE, -- 3 = Consulta
                           p_cod_servicio    IN bw_pag_servicios.cod_servicio%TYPE,
                           p_cod_transaccion IN bw_pag_servicios.nro_transaccion%TYPE, --Identificador unico de transaccion
                           p_pto_cobranza    IN NUMBER default null,
                           p_nro_cuo_hasta   IN NUMBER default null)
    RETURN varchar2 IS
    v_cod_tra_padre ge_movimientos.cod_tra_padre%TYPE := 360;
    v_cod_modulo    ge_cta_clientes.cod_modulo%TYPE;
    v_cod_modalidad ge_cta_clientes.cod_modalidad%TYPE;
    v_en_juicio     pr_cta_prestamos.en_juicio%TYPE;
    v_nro_documento ge_movimientos.nro_documento%TYPE;
    v_cod_rubro     ge_movimientos.cod_rubro%TYPE;
    v_cta_bancaria  ge_movimientos.nro_cuenta%TYPE;
    v_cadena        VARCHAR2(5000):=null;
    v_capital       pr_cuotas.sal_capital%TYPE;
    v_interes       pr_cuotas.sal_interes%TYPE;

    -- variables
    v_tot_capital        NUMBER(18, 2); -- Capital (no se despliega )
    v_tot_interes        NUMBER(18, 2); -- Interes (no se despliega )
    v_tot_int_adelantado NUMBER(18, 2); -- Interes adelantado (no despliega)
    v_tot_mora           NUMBER(18, 2); -- Mora s/capital (no despliega)
    v_tot_moratorio      NUMBER(18, 2); -- Mora s/capital (no despliega)
    v_tot_mora_interes   NUMBER(18, 2); -- Mora s/Interes (DESPLIEGA : Mora s/interes )
    v_tot_mora_int_adel  NUMBER(18, 2); -- Mora interes adelantado (no desp)
    v_tot_impuesto       NUMBER(18, 2); -- Total impuesto (DESPLIEGA : ley 125/91)
    v_tot_cargo          NUMBER(18, 2); -- Total cargo (DESPLIEGA : Cargo + IVA )
    v_tot_car_cobser     NUMBER(18, 2); -- Total cargo por utilización de Cobro de Servicios
    v_tot_cargo_iva      NUMBER(18, 2); -- Total cargo IVA  (no desp)
    v_tot_int_descontado NUMBER(18, 2); -- Total interes descontado (no desp)
    v_tot_punitorio      NUMBER(18, 2); -- Total monto punitorio (DESPLIEGA : Punitorio)
    v_tot_a_cobrar       NUMBER(18, 2); -- Total a cobrar (DESPLIEGA: cap+int+morai+morac+imp+cargo)
    v_importe            NUMBER(16, 2); -- Variable para formatear el monto ingresado por el usuario.
    v_redondeo           NUMBER(3);

    v_cod_moneda       VARCHAR2(1);
    v_cod_usuario      VARCHAR2(10) := upper(USER);
    v_nro_cuenta       VARCHAR2(15);
    v_ped_autorizacion VARCHAR2(1);
    v_cod_banco        VARCHAR2(4);
    v_cod_bco_central  VARCHAR2(4);

    v_concepto               ge_movimientos.concepto%TYPE;
    v_hora                   ge_movimientos.hora%TYPE;
    r_gmovi                  ge_movimientos%ROWTYPE;
    v_cod_ofi_origen         pr_movimientos_his.cod_ofi_origen%TYPE;
    v_dia_mora               pr_cta_prestamos.dia_atraso%TYPE;
    v_usu_ip                 bw_pag_servicios.ip_usuario%TYPE;
    v_usu_terminal           bw_pag_servicios.terminal%TYPE;
    v_nro_min_cuota          pr_cuotas.nro_cuota%TYPE;
    v_fec_vigencia           ge_tas_fechas.fec_vigencia%TYPE;
    v_tip_valor              ge_tasas.tip_valor%TYPE;
    v_tip_tasa               ge_tasas.tipo%TYPE;
    v_cod_persona            ba_personas.cod_persona%TYPE;
    v_cod_tasa               ge_tasas.cod_tasa%TYPE;
    v_nro_cuo_desde          pr_cuotas.nro_cuota%TYPE := 0;
    v_nro_cuo_hasta          pr_cuotas.nro_cuota%TYPE := 0;
    v_cancelar               varchar2(1);
    v_nro_secuencia          ge_movimientos.nro_secuencia%TYPE;
    r_pcpre                  pr_cta_prestamos%rowtype;
    v_nro_solicitud          pr_cta_prestamos.Nro_Solicitud%TYPE;
    v_tipo                   GE_TASAS.TIPO%TYPE;
    v_cob_iva                varchar2(1);
    v_est_solicitud          pr_solicitudes.estado%TYPE;
    v_tip_renovacion         pr_solicitudes.tip_renovacion%TYPE;
    v_des_estado             ba_cod_referencias.significado%TYPE;
    v_des_tip_renov          ba_cod_referencias.significado%TYPE;
    v_val_tas_iva_descontado GE_TAS_FECHAS.VAL_TASA%TYPE;
    v_tot_iva_descontado     NUMBER(18, 2);
    v_cod_transaccion        ge_transacciones.cod_transaccion%TYPE;

    v_entidad            ba_cod_referencias.significado%TYPE := '';
    v_nom_parametro      ba_cod_referencias.significado%TYPE := '';
    v_exist_chq          varchar2(1);
    v_exist_chq_c        varchar2(1);
    v_existe             varchar2(1);
    v_nro_caja           cj_cajas.nro_caja%TYPE := fug_obt_pardinamico('CAJ_PAG_SERVICIOS');
    v_nro_doc_cliente    ba_personas.nro_documento%TYPE := '0';
    v_cuota              pr_cobros.mto_capital%TYPE;
    v_int_mor_cap        pr_cobros.mto_int_moratorio%TYPE := 0;
    v_int_mor_int        pr_cobros.mto_int_mor_int_des%TYPE := 0;
    v_int_mor_ade        pr_cobros.mto_int_mor_adelantado%TYPE := 0;
    v_int_punitorio      pr_cobros.mto_int_punitorio%TYPE := 0;
    v_impuesto           pr_cobros.mto_impuesto%TYPE := 0;
    v_cargo              pr_cobros.mto_cargo%TYPE := 0;
    v_iva                pr_cobros.mto_cargo_iva%TYPE := 0;
    v_mto_capital        pr_cobros.mto_capital%TYPE := 0;
    v_mto_interes        pr_cobros.mto_interes%TYPE := 0;
    v_saldo_capital      pr_cobros.sal_capital_cuo%TYPE := 0;
    v_saldo_interes      pr_cobros.sal_interes_cuo%TYPE := 0;
    v_mto_descontado     pr_cobros.mto_int_descontado%TYPE := 0;
    v_iva5               pr_cobros.mto_cargo_iva%TYPE := 0;
    v_hor_cobro          ge_movimientos.hora%TYPE;
    v_des_banco          ge_bancos.descripcion%type := '';
    v_dat_banco          ge_movimientos.concepto%type := '';
    v_msj_error          varchar2(4000);
    v_encuentra          number(3);
    v_cod_val_tasa       ge_tasas.cod_tasa%TYPE;
    v_fec_val_vigencia   GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
    v_tip_val_valor      GE_TASAS.TIP_VALOR%TYPE;
    v_iva_devuelto       NUMBER(18, 2) := 0; -- Iva devuelto
    v_mod_no_permitidas  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('PRE_MOD_NEGADAS');
    v_cod_ofi_pronet     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('PRE_COD_OFI_PRONET');
    v_cob_juicio         ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CAJ_COB_PRE_JUICIO');
    v_mto_minimo         NUMBER(16, 2);
    v_cod_mon_prestamo   pr_cta_prestamos.cod_moneda%TYPE;
    v_red_pronet         ba_cod_referencias.val_minimo%TYPE;
    v_cod_ent_pronet     ge_entes.cod_ente%type;
    v_red_practipago     ba_cod_referencias.val_minimo%TYPE;
    v_red_infonet        ba_cod_referencias.val_minimo%TYPE;
    v_red_netel          ba_cod_referencias.val_minimo%TYPE;
    v_red_tigo           ba_cod_referencias.val_minimo%TYPE;
    v_cod_ent_practipago ge_entes.cod_ente%type;
    v_cod_ent_infonet    ge_entes.cod_ente%type;
    v_cod_ent_netel      ge_entes.cod_ente%type;
    v_cod_ent_tigo       ge_entes.cod_ente%type;
    v_cod_transc         bw_pag_servicios.nro_transaccion%type;
    v_tot_iva_incluido   NUMBER(18, 2); -- Total cargo por utilización de Cobro de Servicios
    v_lote               bw_pag_servicios.nro_lote%type := 0;
    v_existe_bc          varchar2(1);

  BEGIN
    --inicializo variables para que no queden con mensajes anteriores
    v_cod_retorno    := '000';
    v_des_retorno    := 'OK';
    --
    v_tot_a_cobrar := null;
    v_hor_cobro    := v_hor_actual;
    --v_hor_cobro := pag_gen.fu_obt_sig_segundo(v_hor_actual);
    v_hor_cobro  := fug_obt_hor_disponible(v_fec_actual,
                                           v_hor_actual,
                                           user,
                                           'N');
    v_fec_actual := pag_cal.fu_obt_fec_actual(3); -- fecha de hoy
    lp_ver_horario;
    --v_red_pago := 2; --nr
    v_concepto := 'Cobros Prestamos ';
    begin
      select 'S'
        into v_existe_bc
        from ba_cod_referencias t
       where dominio = 'PRE_COM_TRA_PAGSER'
         and val_minimo = p_pto_cobranza;
    exception
      when no_data_found then
        v_existe_bc := 'N';
    end;
    if v_existe_bc = 'S' then
      v_red_pago := p_pto_cobranza;
    else
      v_red_pago := 0;
    end if;
    -----------------------

    BEGIN
      select 'S'
        into v_existe
        from ba_cod_referencias
       where dominio = 'PRE_COM_TRA_PAGSER'
         and val_minimo = v_red_pago;
      v_entidad := FUE_OBT_DES_REFERENCIA('PRE_COM_TRA_PAGSER', v_red_pago);
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Error en el proceso';
    END;
    v_concepto := v_concepto || v_entidad;
    -- Recuperar la cuenta, esto es, por si se ingresa C.I. o Nro. Cuenta indistintamente
    -- como parametro.
    BEGIN
      SELECT c.nro_cuenta, a.nro_documento, s.cod_moneda
        INTO v_nro_cuenta, v_nro_doc_cliente, v_cod_mon_prestamo
        FROM ba_personas a, ge_cta_clientes c, pr_cta_prestamos s
       WHERE a.cod_persona = c.cod_persona
         AND c.nro_cuenta = s.nro_cuenta
         AND (c.nro_cuenta = p_nro_cuenta OR
             replace(a.nro_documento, '-', '') = p_nro_cuenta)
         AND c.relacion = 'P'
         AND s.estado <> 'N';
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_tra_incorrecta;
        v_des_retorno := 'Cuenta inexistente.';
    END;
    --Controla que el nro de cuota cobrada sea el correcto
    BEGIN
      SELECT MIN(nro_cuota)
        INTO v_nro_min_cuota
        FROM pr_cuotas
       WHERE nro_cuenta = p_nro_cuenta
         AND nro_cuota > 0
         AND estado != 'N';
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_cta_incorrecta;
        v_des_retorno := 'Cuenta inexistente.';
      WHEN OTHERS THEN
        v_cod_retorno := pag_ser.v_cta_incorrecta;
        v_des_retorno := 'Error en pr_cuotas.';
    END;

    IF p_nro_cuota != 0 and p_nro_cuota != v_nro_min_cuota THEN
      v_cod_retorno := pag_ser.v_nro_cuo_incorrecto;
      v_des_retorno := 'Cuota no corresponde cobrar';
    END IF;

    /*v_importe := to_number(substr(lpad(p_importe, 15, '0'), 1, 13) || '.' ||
    substr(lpad(p_importe, 15, '0'), 14, 2), '9999999999999.99');*/
    v_importe := to_number(p_importe); --nr
    v_hora    := to_char(SYSDATE, 'hh24:mi:ss');
    pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, r_ctapre); --Obtener datos del prestamo.

    v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);
    v_cod_modulo     := r_ctapre.cod_modulo;
    v_cod_modalidad  := r_ctapre.cod_modalidad;
    v_en_juicio      := r_ctapre.en_juicio;
    v_usu_ip         := substr(sys_context('USERENV', 'IP_ADDRESS'),1,20);
    v_usu_terminal   := substr(sys_context('USERENV', 'HOST'),1,25);
    --v_cod_rubro      := fug_obt_pardinamico('PRE_COD_RUB_COBRO', NULL, NULL, r_ctapre.cod_moneda);

    If v_entidad = 'PRONET' then
      v_nom_parametro := 'COBRO';
    else
      v_nom_parametro := v_entidad;
    End if;

    v_cta_bancaria := fug_obt_pardinamico('PRE_CTA_BAN_' || v_nom_parametro,
                                          NULL,
                                          NULL,
                                          r_ctapre.cod_moneda);

    BEGIN
      SELECT val_minimo, abreviatura
        INTO v_red_pronet, v_cod_ent_pronet
        FROM ba_cod_referencias
       WHERE dominio = 'PRE_COM_TRA_PAGSER'
         AND significado = 'PRONET'; --tigo es igual pronet
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Error en el proceso';
    END;
    --se agrega tigo nrecalde
    BEGIN
      SELECT val_minimo, abreviatura
        INTO v_red_tigo, v_cod_ent_tigo
        FROM ba_cod_referencias
       WHERE dominio = 'PRE_COM_TRA_PAGSER'
         AND significado = 'TIGO';
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Error en el proceso';
    END;
    --
    BEGIN
      SELECT val_minimo, abreviatura
        INTO v_red_practipago, v_cod_ent_practipago
        FROM ba_cod_referencias
       WHERE dominio = 'PRE_COM_TRA_PAGSER'
         AND significado = 'PRACTIPAGO'; -- comentamos es documenta
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Error en el proceso';
    END;

    -- INFONET --
    BEGIN
      SELECT val_minimo, abreviatura
        INTO v_red_infonet, v_cod_ent_infonet
        FROM ba_cod_referencias
       WHERE dominio = 'PRE_COM_TRA_PAGSER'
         AND significado = 'INFONET'; --bancard
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Error en el proceso';
    END;

    BEGIN
      SELECT val_minimo, abreviatura
        INTO v_red_netel, v_cod_ent_netel
        FROM ba_cod_referencias
       WHERE dominio = 'PRE_COM_TRA_PAGSER'
         AND significado = 'NETEL';
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Error en el proceso';
    END;

    --pronet
    IF v_red_pago = v_red_pronet THEN
      --v_cta_bancaria := fug_obt_pardinamico('PRE_CTA_BAN_COBRO', NULL, NULL, r_ctapre.cod_moneda);
      if v_cod_ent_pronet is not null then
        if r_ctapre.cod_moneda = 'GS' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_pronet,
                                          'COD_RUB_INGRESO');
        elsif r_ctapre.cod_moneda = 'USD' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_pronet,
                                          'COD_RUB_INGRESO_USD');
        end if;
      end if;
      --documenta
    ELSIF v_red_pago = v_red_practipago THEN
      --v_cta_bancaria := fug_obt_pardinamico('PRE_CTA_BAN_PRACTIPAGO', NULL, NULL,r_ctapre.cod_moneda);
      if v_cod_ent_practipago is not null then
        if r_ctapre.cod_moneda = 'GS' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_practipago,
                                          'COD_RUB_INGRESO');
        elsif r_ctapre.cod_moneda = 'USD' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_practipago,
                                          'COD_RUB_INGRESO_USD');
        end if;
      end if;
    ELSIF v_red_pago = v_red_infonet THEN
      --v_cta_bancaria := fug_obt_pardinamico('PRE_CTA_BAN_INFONET', NULL, NULL,r_ctapre.cod_moneda);
      if v_cod_ent_infonet is not null then
        if r_ctapre.cod_moneda = 'GS' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_infonet,
                                          'COD_RUB_INGRESO');
        elsif r_ctapre.cod_moneda = 'USD' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_infonet,
                                          'COD_RUB_INGRESO_USD');
        end if;
      end if;
    ELSIF v_red_pago = v_red_netel THEN
      --v_cta_bancaria := fug_obt_pardinamico('PRE_CTA_BAN_NETEL', NULL, NULL,r_ctapre.cod_moneda);
      if v_cod_ent_netel is not null then
        if r_ctapre.cod_moneda = 'GS' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_netel,
                                          'COD_RUB_INGRESO');
        elsif r_ctapre.cod_moneda = 'USD' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_netel,
                                          'COD_RUB_INGRESO_USD');
        end if;
      end if;
      --tigo
    ELSIF v_red_pago = v_red_tigo THEN
      if v_cod_ent_tigo is not null then
        if r_ctapre.cod_moneda = 'GS' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_tigo, 'COD_RUB_INGRESO');
        elsif r_ctapre.cod_moneda = 'USD' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_tigo,
                                          'COD_RUB_INGRESO_USD');
        end if;
      end if;
    END IF;

    BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := v_cod_modulo;
    END;

    --Validar monto mínimo de cobro
    if (nvl(fug_obt_pardinamico('PRE_MTO_MIN_CONTROL'), 'N') = 'S') then
      v_mto_minimo := nvl(fug_obt_pardinamico('PRE_COB_SER_MINIMO',
                                              NULL,
                                              NULL,
                                              v_cod_mon_prestamo),
                          0);
      if v_importe < nvl(v_mto_minimo, 0) then
        v_cod_retorno := pag_ser.v_err_mto_minimo;
        v_des_retorno := 'Monto inferior a mínimo';
      end if;
    end if;

    IF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_local THEN
      v_cod_moneda := '1';
    ELSIF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_fuerte THEN
      v_cod_moneda := '2';
    ELSE
      v_cod_retorno := pag_ser.v_mon_incorrecta;
      v_des_retorno := 'Moneda incorrecta.';
    END IF;
    /*IF p_cod_moneda <> v_cod_moneda THEN
       v_cod_retorno := pag_ser.v_mon_incorrecta;
       v_des_retorno := 'Moneda incorrecta.';
    END IF;*/ -- se comenta por como llega el parametro de moneda
    IF nvl(v_cob_juicio, 'N') = 'N' THEN
      IF v_en_juicio = 'S' THEN
        v_cod_retorno := pag_ser.v_tra_incorrecta;
        v_des_retorno := 'Préstamo en juicio.';
      END IF;
    END IF;

    v_mod_no_permitidas := ',' || v_mod_no_permitidas || ',';

    IF instr(v_mod_no_permitidas, ',' || v_cod_modalidad || ',') > 0 AND
       nvl(fug_obt_paradicional(p_nro_cuenta, 'PRE_EXC_PLANILLA'), 'N') = 'N' THEN
      v_cod_retorno := pag_ser.v_tra_incorrecta;
      v_des_retorno := 'Modalidad no permitida.';
    END IF;

    /*      IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
             v_existe := 'N';
             begin
                 select 'S'
                   into v_existe
                   from bw_pag_servicios b
                  where b.nro_transaccion = p_cod_transaccion
                    and b.red_pago = v_red_pago;
              exception
               WHEN OTHERS THEN
                    null;
              end;
              if v_existe = 'S' then
                  v_cod_retorno := pag_ser.v_tra_incorrecta;
                  v_des_retorno := 'Transaccion ya registrada.';
              end if;
          END IF;
    */
    --
    --si tiene rubro es porque puede continuar. se setean las variables de error
    if v_cod_rubro is not null then
      v_cod_retorno := '000';
      v_des_retorno := 'OK';
    end if;
    IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
      pap_pre.pr_ini_autorizacion;

      if p_nro_cuota = 0 then
        v_cod_tra_padre := 359;
        v_nro_cuo_desde := 0;
        v_nro_cuo_hasta := 999;
        v_cancelar      := 'T';
      else
        v_nro_cuo_desde := p_nro_cuota;
        if p_nro_cuo_hasta is not null then
          v_nro_cuo_hasta := p_nro_cuo_hasta;
        else
          v_nro_cuo_hasta := p_nro_cuota;
        end if;
        v_cancelar := 'N';
      end if;

      if p_nro_cuota = 0 and v_mod_estado != 2 then
        v_cod_retorno := pag_ser.v_err_cie_cancela;
        v_des_retorno := 'Proc.cierre-No Cancelaciones';
      end if;

      if p_nro_cuota = 0 then
        begin

          --Consulta para obtener valor de cancelación.
          pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                      v_fec_actual,
                                      0,
                                      999,
                                      v_cod_ofi_origen,
                                      v_tot_a_cobrar,
                                      v_cod_error,
                                      v_des_retorno,
                                      v_tot_capital,
                                      v_tot_interes,
                                      v_tot_int_adelantado,
                                      v_tot_mora,
                                      v_tot_mora_interes,
                                      v_tot_mora_int_adel,
                                      v_tot_punitorio,
                                      v_tot_impuesto,
                                      v_tot_cargo,
                                      v_tot_cargo_iva,
                                      v_tot_int_descontado,
                                      v_dia_mora,
                                      359,
                                      'T');

          --calcula el iva devuelto
          --- Inicializar variables de cobro
          --pap_pre.pr_ini_var_cobro;
          pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, r_pcpre);
          pag_gen.pr_obt_val_tasa(6,
                                  r_pcpre.cod_modalidad,
                                  r_pcpre.cod_oficina,
                                  p_nro_cuenta,
                                  r_pcpre.cod_moneda,
                                  v_tot_int_descontado,
                                  'N',
                                  v_cod_val_tasa,
                                  1708,
                                  v_fec_actual,
                                  v_val_tas_iva_descontado,
                                  v_fec_val_vigencia,
                                  v_tip_val_valor,
                                  v_tipo);

          --verificar redondeo
          v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                            6,
                                            r_pcpre.cod_modalidad,
                                            r_pcpre.cod_moneda);

          IF fug_obt_pardinamico('PRE_IVA_INT_DESCONTADO') = 'S' THEN
            -- Verificar si se cobro iva en la solicitud
            BEGIN
              SELECT 'S'
                INTO v_cob_iva
                FROM pr_sol_cargos
               WHERE nro_solicitud = r_pcpre.nro_solicitud
                 AND cod_transaccion = 709;
            EXCEPTION
              WHEN others THEN
                v_cob_iva := 'N';
            END;
            IF v_cob_iva = 'S' then
              v_iva_devuelto := round(nvl(v_tot_int_descontado, 0) *
                                      (v_val_tas_iva_descontado / 100),
                                      v_redondeo);
            ELSE
              v_iva_devuelto := 0;
            END IF;
          ELSE
            v_iva_devuelto := 0;
          END IF;

        exception
          WHEN OTHERS THEN
            pag_ser.g_cod_error := 999;
            pag_ser.g_men_error := SQLERRM;
        end;
      else
        pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                    v_fec_actual,
                                    v_nro_cuo_desde,
                                    v_nro_cuo_hasta,
                                    v_cod_ofi_origen,
                                    v_importe,
                                    v_cod_error,
                                    v_des_retorno,
                                    v_tot_capital,
                                    v_tot_interes,
                                    v_tot_int_adelantado,
                                    v_tot_mora,
                                    v_tot_mora_interes,
                                    v_tot_mora_int_adel,
                                    v_tot_punitorio,
                                    v_tot_impuesto,
                                    v_tot_cargo,
                                    v_tot_cargo_iva,
                                    v_tot_int_descontado,
                                    v_dia_mora,
                                    v_cod_tra_padre,
                                    v_cancelar,
                                    'N');
      end if;

      IF v_cod_error <> 0 THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Error en el proceso';
      ELSE
        v_tot_moratorio := nvl(v_tot_mora, 0) + nvl(v_tot_mora_int_adel, 0) +
                           nvl(v_tot_mora_interes, 0);
        v_tot_cargo     := nvl(v_tot_cargo, 0);
        v_tot_a_cobrar  := nvl(v_tot_capital, 0) + nvl(v_tot_interes, 0) +
                           nvl(v_tot_moratorio, 0) + nvl(v_tot_impuesto, 0) +
                           nvl(v_tot_int_adelantado, 0) +
                           nvl(v_tot_cargo, 0) + nvl(v_tot_punitorio, 0);

        --Verificar si aplica el cobro de comisión por utilizar Pronet.
        IF nvl(fug_obt_pardinamico('PRE_COM_PAGSER'), 'N') = 'S' and
           v_red_pago != 4 THEN
          BEGIN
            v_cod_transaccion := fue_obt_val_max_referencia('PRE_COM_TRA_PAGSER',
                                                            v_red_pago);
          EXCEPTION
            WHEN no_data_found THEN
              v_cod_retorno := pag_ser.v_err_proceso;
              v_des_retorno := 'Error en el proceso';
          END;

          v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                            null,
                                            null,
                                            r_ctapre.cod_moneda);
          pag_gen.pr_obt_val_tasa(r_ctapre.cod_modulo,
                                  r_ctapre.cod_modalidad,
                                  r_ctapre.cod_oficina,
                                  v_nro_cuenta,
                                  r_ctapre.cod_moneda,
                                  v_tot_a_cobrar,
                                  'N',
                                  v_cod_tasa,
                                  v_cod_transaccion,
                                  sysdate,
                                  v_tot_car_cobser,
                                  v_fec_vigencia,
                                  v_tip_valor,
                                  v_tip_tasa,
                                  v_cod_persona);

          IF v_entidad = 'PRACTIPAGO' THEN
            IF fug_obt_pardinamico('PRE_ULT_TRA_PRACTIPAGO') is not null THEN
              if v_tot_a_cobrar >=
                 fug_obt_pardinamico('PRE_ULT_TRA_PRACTIPAGO') THEN
                v_cod_tasa := null;

                pag_gen.pr_obt_val_tasa(r_ctapre.cod_modulo,
                                        r_ctapre.cod_modalidad,
                                        r_ctapre.cod_oficina,
                                        v_nro_cuenta,
                                        r_ctapre.cod_moneda,
                                        v_tot_a_cobrar,
                                        'N',
                                        v_cod_tasa,
                                        v_cod_transaccion,
                                        sysdate,
                                        v_tot_car_cobser,
                                        v_fec_vigencia,
                                        v_tip_valor,
                                        v_tip_tasa,
                                        v_cod_persona);

                v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                         0) *
                                                                   nvl(v_tot_car_cobser,
                                                                         0)) / 100)),
                                          v_redondeo);
              else
                --sino, toma la tasa por rangos.
                v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
              end if;
            ELSE
              -- calculo para ACI

              --se analiza comision total calculada con respecto a valor en parametros
              v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                       0) *
                                                                 nvl(v_tot_car_cobser,
                                                                       0)) / 100)),
                                        v_redondeo);
              if fug_obt_pardinamico('PRE_MTO_SUP_PRACTIPAGO') is not null and
                 fug_obt_pardinamico('PRE_MTO_INF_PRACTIPAGO') is not null THEN
                if v_tot_car_cobser <
                   fug_obt_pardinamico('PRE_MTO_INF_PRACTIPAGO') THEN
                  v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_PRACTIPAGO');
                  v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                elsif v_tot_car_cobser >
                      fug_obt_pardinamico('PRE_MTO_SUP_PRACTIPAGO') THEN
                  v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_PRACTIPAGO');
                  v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                else
                  v_tot_car_cobser := round(v_tot_car_cobser / 1.1);
                end if;
              end if;

              v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
            END IF;

          ELSIF v_entidad = 'INFONET' THEN
            --se analiza comision total calculada con respecto a valor en parametros
            v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                     0) *
                                                               nvl(v_tot_car_cobser,
                                                                     0)) / 100)),
                                      v_redondeo);
            if fug_obt_pardinamico('PRE_MTO_SUP_INFONET') is not null and
               fug_obt_pardinamico('PRE_MTO_INF_INFONET') is not null THEN
              if v_tot_car_cobser <
                 fug_obt_pardinamico('PRE_MTO_INF_INFONET') THEN
                v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_INFONET');
                v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
              elsif v_tot_car_cobser >
                    fug_obt_pardinamico('PRE_MTO_SUP_INFONET') THEN
                v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_INFONET');
                v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
              else
                v_tot_car_cobser := round(v_tot_car_cobser / 1.1);
              end if;
            end if;

            v_tot_car_cobser := nvl(v_tot_car_cobser, 0);

          ELSIF v_entidad = 'PRONET' THEN
            IF fug_obt_pardinamico('PRE_ULT_TRA_PRONET') is not null and
               fug_obt_pardinamico('PRE_PRI_TRA_PRONET') is not null THEN
              if v_tot_a_cobrar <=
                 fug_obt_pardinamico('PRE_ULT_TRA_PRONET') and
                 v_tot_a_cobrar > fug_obt_pardinamico('PRE_PRI_TRA_PRONET') THEN
                v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                         0) *
                                                                   nvl(v_tot_car_cobser,
                                                                         0)) / 100)),
                                          v_redondeo);
              else
                v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
              end if;
            ELSE
              --se analiza comision total calculada con respecto a valor en parametros
              v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                       0) *
                                                                 nvl(v_tot_car_cobser,
                                                                       0)) / 100)),
                                        v_redondeo);
              if fug_obt_pardinamico('PRE_MTO_SUP_PRONET') is not null and
                 fug_obt_pardinamico('PRE_MTO_INF_PRONET') is not null THEN
                if v_tot_car_cobser <
                   fug_obt_pardinamico('PRE_MTO_INF_PRONET') THEN
                  v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_PRONET');
                  v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                elsif v_tot_car_cobser >
                      fug_obt_pardinamico('PRE_MTO_SUP_PRONET') THEN
                  v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_PRONET');
                  v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                else
                  v_tot_car_cobser := round(v_tot_car_cobser / 1.1);
                end if;
              end if;
              v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
            END IF;
            --TIGO----------------------------------------------------------------------------------------------------------------------------------
          ELSIF v_entidad = 'TIGO' THEN
            IF fug_obt_pardinamico('PRE_ULT_TRA_TIGO') is not null and
               fug_obt_pardinamico('PRE_PRI_TRA_TIGO') is not null THEN
              if v_tot_a_cobrar <= fug_obt_pardinamico('PRE_ULT_TRA_TIGO') and
                 v_tot_a_cobrar > fug_obt_pardinamico('PRE_PRI_TRA_TIGO') THEN
                v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                         0) *
                                                                   nvl(v_tot_car_cobser,
                                                                         0)) / 100)),
                                          v_redondeo);
              else
                v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
              end if;
            ELSE
              --se analiza comision total calculada con respecto a valor en parametros
              v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                       0) *
                                                                 nvl(v_tot_car_cobser,
                                                                       0)) / 100)),
                                        v_redondeo);
              if fug_obt_pardinamico('PRE_MTO_SUP_TIGO') is not null and
                 fug_obt_pardinamico('PRE_MTO_INF_TIGO') is not null THEN
                if v_tot_car_cobser <
                   fug_obt_pardinamico('PRE_MTO_INF_TIGO') THEN
                  v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_TIGO');
                  v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                elsif v_tot_car_cobser >
                      fug_obt_pardinamico('PRE_MTO_SUP_TIGO') THEN
                  v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_TIGO');
                  v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
                else
                  v_tot_car_cobser := round(v_tot_car_cobser / 1.1);
                end if;
              end if;
              v_tot_car_cobser := nvl(v_tot_car_cobser, 0);
            END IF;
            ----------------------------------------------------------------------------------------------------------------------------------------
          ELSIF v_red_netel = v_red_pago THEN
            --se analiza comision total calculada con respecto a valor en parametros
            v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                     0) *
                                                               nvl(v_tot_car_cobser,
                                                                     0)) / 100)),
                                      v_redondeo);
            if fug_obt_pardinamico('PRE_MTO_SUP_NETEL') is not null and
               fug_obt_pardinamico('PRE_MTO_INF_NETEL') is not null THEN
              if v_tot_car_cobser <
                 fug_obt_pardinamico('PRE_MTO_INF_NETEL') THEN
                v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_INF_NETEL');
                v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
              elsif v_tot_car_cobser >
                    fug_obt_pardinamico('PRE_MTO_SUP_NETEL') THEN
                v_tot_iva_incluido := fug_obt_pardinamico('PRE_MTO_SUP_NETEL');
                v_tot_car_cobser   := round(v_tot_iva_incluido / 1.1);
              else
                v_tot_car_cobser := round(v_tot_car_cobser / 1.1);
              end if;
            end if;

            v_tot_car_cobser := nvl(v_tot_car_cobser, 0);

          ELSE
            v_tot_car_cobser := round(pag_gen.fu_obt_val_final(((nvl(v_tot_a_cobrar,
                                                                     0) *
                                                               nvl(v_tot_car_cobser,
                                                                     0)) / 100)),
                                      v_redondeo);
          END IF;

          INSERT INTO pr_cta_gastos
            (nro_cuenta,
             cod_transaccion,
             cod_moneda,
             monto,
             fec_ingreso,
             fec_vencimiento,
             fec_ini_vigencia,
             cod_modulo,
             cod_modalidad,
             nro_solicitud,
             hor_ult_pago)
          VALUES
            (v_nro_cuenta,
             v_cod_transaccion,
             r_ctapre.cod_moneda,
             v_tot_car_cobser,
             v_fec_actual,
             r_ctapre.fec_vencimiento,
             r_ctapre.fec_inicio,
             r_ctapre.cod_modulo,
             r_ctapre.cod_modalidad,
             r_ctapre.nro_solicitud,
             v_hor_cobro);
          v_tot_a_cobrar := 0; --se cera para obtener deuda con la comisión más los cargos en caso de préstamos con atrasos
          --Se vuelve a consultar el préstamo para obtener el cargo, calculado con su impuesto.

          pap_pre.pr_ini_autorizacion;
          pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                      v_fec_actual,
                                      v_nro_cuo_desde,
                                      v_nro_cuo_hasta,
                                      v_cod_ofi_origen,
                                      v_importe,
                                      v_cod_error,
                                      v_des_retorno,
                                      v_tot_capital,
                                      v_tot_interes,
                                      v_tot_int_adelantado,
                                      v_tot_mora,
                                      v_tot_mora_interes,
                                      v_tot_mora_int_adel,
                                      v_tot_punitorio,
                                      v_tot_impuesto,
                                      v_tot_cargo,
                                      v_tot_cargo_iva,
                                      v_tot_int_descontado,
                                      v_dia_mora,
                                      v_cod_tra_padre,
                                      v_cancelar,
                                      'N');

          v_tot_mora     := nvl(v_tot_mora, 0) +
                            nvl(v_tot_mora_int_adel, 0) +
                            nvl(v_tot_mora_interes, 0);
          v_tot_cargo    := nvl(v_tot_cargo, 0);
          v_tot_a_cobrar := nvl(v_tot_capital, 0) + nvl(v_tot_interes, 0) +
                            nvl(v_tot_mora, 0) + nvl(v_tot_impuesto, 0) +
                            nvl(v_tot_int_adelantado, 0) +
                            nvl(v_tot_cargo, 0) + nvl(v_tot_punitorio, 0);

        END IF;
      END IF;

      --
      IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
        IF nvl(v_tot_a_cobrar, 0) = 0 THEN
          v_cod_retorno := pag_ser.v_cuo_inexistente;
          v_des_retorno := 'Cuota inexistente o cancelada';
        END IF;

        IF nvl(v_importe, 0) >
           (nvl(v_tot_a_cobrar, 0) - nvl(v_iva_devuelto, 0)) AND
           v_tot_a_cobrar <> 0 THEN
          v_cod_retorno := pag_ser.v_imp_mayor;
          v_des_retorno := 'Monto mayor al de la cuota';
        END IF;

        IF p_nro_cuota = 0 AND nvl(v_importe, 0) < (nvl(v_tot_a_cobrar, 0) -
           nvl(v_iva_devuelto, 0)) AND v_tot_a_cobrar <> 0 THEN
          v_cod_retorno := pag_ser.v_imp_mayor;
          v_des_retorno := 'Monto menor al Saldo';
        END IF;

        v_nro_documento := fug_obt_lla_pardinamico('NRO_RECIBO',
                                                   r_ctapre.cod_modulo,
                                                   r_ctapre.cod_modalidad,
                                                   r_ctapre.cod_moneda,
                                                   nvl(v_cod_ofi_pronet,
                                                       r_ctapre.cod_oficina)) + 1;

        prg_act_par_dinamico('NRO_RECIBO',
                             r_ctapre.cod_modulo,
                             r_ctapre.cod_modalidad,
                             r_ctapre.cod_moneda,
                             nvl(v_cod_ofi_pronet, r_ctapre.cod_oficina),
                             v_nro_documento);
        --
        IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
          --lp_ver_horario;
          --
          IF v_horario IN ('T', 'N') THEN
            if fug_obt_pardinamico('PRE_OBT_PTO_COBRANZA') = 'S' and
               v_red_pago = 4 then
              v_cod_retorno := pag_ser.v_cie_diario;
              v_des_retorno := 'Sistema en proceso de Cierre.';
            end if;

            IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
              -- Tarde, Noche
              if p_nro_cuota = 0 then
                --cancelación del préstamo
                SELECT MIN(c.nro_cuota)
                  INTO v_nro_cuo_desde
                  FROM pr_cuotas c
                 WHERE c.nro_cuenta = v_nro_cuenta
                   AND c.estado != 'N'
                   AND nro_cuota != 0;

                SELECT MAX(c.nro_cuota)
                  INTO v_nro_cuo_hasta
                  FROM pr_cuotas c
                 WHERE c.nro_cuenta = v_nro_cuenta
                   AND c.estado != 'N';
              end if;

              INSERT INTO pr_cobros_noc
                (nro_cuenta,
                 nro_cuota_desde,
                 nro_cuota_hasta,
                 fecha,
                 hora,
                 estado,
                 mto_cobrado,
                 cod_ofi_origen,
                 cod_mod_padre,
                 cod_mad_padre,
                 cod_tra_padre,
                 nro_secuencia)
              VALUES
                (v_nro_cuenta,
                 v_nro_cuo_desde,
                 v_nro_cuo_hasta,
                 v_fec_actual,
                 v_hor_cobro,
                 'I',
                 v_tot_a_cobrar,
                 v_cod_ofi_origen,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_tra_padre,
                 nvl(v_nro_secuencia, 1));

              IF nvl(fug_obt_pardinamico('PRE_COM_PAGSER'), 'N') = 'S' THEN
                INSERT INTO pr_cta_gastos
                  (nro_cuenta,
                   cod_transaccion,
                   cod_moneda,
                   monto,
                   fec_ingreso,
                   fec_vencimiento,
                   fec_ini_vigencia,
                   cod_modulo,
                   cod_modalidad,
                   nro_solicitud,
                   hor_ult_pago)
                VALUES
                  (v_nro_cuenta,
                   v_cod_transaccion,
                   r_ctapre.cod_moneda,
                   v_tot_car_cobser,
                   v_fec_actual,
                   r_ctapre.fec_vencimiento,
                   r_ctapre.fec_inicio,
                   r_ctapre.cod_modulo,
                   r_ctapre.cod_modalidad,
                   r_ctapre.nro_solicitud,
                   v_hor_cobro);
              END IF;

              if v_entidad = 'PRONET' then
                v_cod_transc := v_nro_cuenta;
                begin
                  select nvl(max(to_number(nro_lote)), 0) + 1
                    into v_lote
                    from bw_pag_servicios
                   where nro_cuenta = v_nro_cuenta
                     and nro_transaccion = v_cod_transc;
                exception
                  when no_data_found then
                    v_lote := 0;
                end;
              else
                v_cod_transc := p_cod_transaccion;
              end if;

              INSERT INTO bw_pag_servicios
                (nro_cuenta,
                 cod_servicio,
                 fecha,
                 hora,
                 nro_transaccion,
                 nro_lote,
                 ip_usuario,
                 terminal,
                 cod_moneda,
                 mto_transaccion,
                 mto_comision,
                 mto_mora,
                 mto_interes,
                 reversado,
                 mto_debito,
                 cod_mon_servicio,
                 tip_pago,
                 cod_banco,
                 nro_cheque,
                 red_pago,
                 pto_cobranza,
                 nro_recibo,
                 mto_capital,
                 mto_impuesto,
                 mto_int_adelantado,
                 mto_punitorio,
                 mto_iva_devuelto,
                 cod_rubro)
              VALUES
                (v_nro_cuenta,
                 p_cod_servicio,
                 v_fec_actual,
                 v_hor_cobro,
                 v_cod_transc,
                 v_lote,
                 v_usu_ip,
                 v_usu_terminal,
                 r_ctapre.cod_moneda,
                 v_importe,
                 v_tot_cargo,
                 v_tot_mora,
                 v_tot_interes,
                 'N',
                 v_importe,
                 NULL /*to_number(p_cod_moneda)*/,
                 p_tip_pago,
                 p_cod_banco,
                 p_nro_cheque,
                 v_red_pago,
                 p_pto_cobranza,
                 v_nro_documento,
                 v_tot_capital,
                 v_tot_impuesto,
                 v_tot_int_adelantado,
                 v_tot_punitorio,
                 nvl(v_iva_devuelto, 0),
                 v_cod_rubro);
            END IF;

          ELSE
            pap_pre.pr_ini_var_cobro;
            pap_pre.pr_ini_autorizacion;

            if p_nro_cuota = 0 then
              begin
                IF p_nro_cuota = 0 AND
                   nvl(v_importe, 0) <
                   (nvl(v_tot_a_cobrar, 0) - nvl(v_iva_devuelto, 0)) AND
                   v_tot_a_cobrar <> 0 THEN
                  v_cod_retorno := pag_ser.v_imp_mayor;
                  v_des_retorno := 'Monto menor al Saldo';
                END IF;

                pap_pre.pr_can_prestamo(v_nro_cuenta,
                                        nvl(v_importe, 0) +
                                        nvl(v_iva_devuelto, 0),
                                        'N',
                                        v_cod_ofi_origen,
                                        'T',
                                        v_fec_actual,
                                        v_hor_cobro,
                                        v_nro_secuencia);
              exception
                WHEN OTHERS THEN
                  v_msj_error := SQLERRM;
                  SELECT INSTR(v_msj_error, 'Monto a abonar no alcanza')
                    INTO v_encuentra
                    FROM DUAL;
                  if v_encuentra > 0 then
                    v_cod_retorno := pag_ser.v_mto_can_insuficiente;
                    v_des_retorno := 'Monto abonado insuficiente';
                  else
                    pag_ser.g_cod_error := 999;
                    pag_ser.g_men_error := SQLERRM;
                    v_cod_retorno       := v_err_proceso;
                    v_des_retorno       := SQLERRM;
                  end if;
                  rollback;
              end;
            else
              begin
                pap_pre.pr_cob_prestamo(v_nro_cuenta,
                                        v_importe,
                                        v_ped_autorizacion,
                                        v_cod_ofi_origen,
                                        v_nro_cuo_desde,
                                        v_nro_cuo_hasta,
                                        v_concepto,
                                        v_fec_actual,
                                        v_hor_cobro,
                                        v_nro_secuencia,
                                        v_cod_tra_padre,
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        'N',
                                        NULL);
              exception
                WHEN OTHERS THEN
                  v_cod_retorno := v_err_proceso;
                  v_des_retorno := SQLERRM;
                  rollback;
              end;
            end if;

            IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
              if v_entidad = 'PRONET' then
                v_cod_transc := v_nro_cuenta;
                begin
                  select nvl(max(to_number(nro_lote)), 0) + 1
                    into v_lote
                    from bw_pag_servicios
                   where nro_cuenta = v_nro_cuenta
                     and nro_transaccion = v_cod_transc;
                exception
                  when no_data_found then
                    v_lote := 0;
                end;
              else
                v_cod_transc := p_cod_transaccion;
              end if;

              INSERT INTO bw_pag_servicios
                (nro_cuenta,
                 cod_servicio,
                 fecha,
                 hora,
                 nro_transaccion,
                 nro_lote,
                 ip_usuario,
                 terminal,
                 cod_moneda,
                 mto_transaccion,
                 mto_comision,
                 mto_mora,
                 mto_interes,
                 reversado,
                 mto_debito,
                 cod_mon_servicio,
                 tip_pago,
                 cod_banco,
                 nro_cheque,
                 red_pago,
                 pto_cobranza,
                 nro_recibo,
                 mto_capital,
                 mto_impuesto,
                 mto_int_adelantado,
                 mto_punitorio,
                 mto_iva_devuelto)
              VALUES
                (v_nro_cuenta,
                 p_cod_servicio,
                 v_fec_actual,
                 v_hor_cobro,
                 v_cod_transc,
                 v_lote,
                 v_usu_ip,
                 v_usu_terminal,
                 r_ctapre.cod_moneda,
                 v_tot_a_cobrar,
                 v_tot_cargo,
                 v_tot_mora,
                 v_tot_interes,
                 'N',
                 v_tot_a_cobrar,
                 null /* to_number(p_cod_moneda)*/,
                 p_tip_pago,
                 p_cod_banco,
                 p_nro_cheque,
                 v_red_pago,
                 p_pto_cobranza,
                 v_nro_documento,
                 v_tot_capital,
                 v_tot_impuesto,
                 v_tot_int_adelantado,
                 v_tot_punitorio,
                 nvl(v_iva_devuelto, 0));

              IF v_cod_rubro is not null and p_nro_cheque is null then
                -- Movimiento contra rubro contable --
                v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
                r_gmovi.cod_usuario   := user;
                r_gmovi.hora          := v_hor_cobro;
                r_gmovi.fecha         := v_fec_actual;
                r_gmovi.nro_secuencia := v_nro_secuencia;
                r_gmovi.cod_modulo    := v_cod_modulo;
                r_gmovi.cod_modalidad := v_cod_modalidad;
                r_gmovi.cod_oficina   := v_cod_ofi_origen;
                r_gmovi.cod_moneda    := r_ctapre.cod_moneda;
                r_gmovi.fec_valor     := v_fec_actual;
                r_gmovi.cod_tra_padre := v_cod_tra_padre;
                r_gmovi.cod_mod_padre := v_cod_modulo;
                r_gmovi.cod_mad_padre := v_cod_modalidad;
                --Transaccion COBRO DE CUENTA CONTABLE
                r_gmovi.cod_transaccion := 842;
                r_gmovi.monto           := v_importe;
                r_gmovi.nro_documento   := v_nro_documento;
                r_gmovi.nro_documento3  := p_nro_cuota;
                r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.concepto        := 'Cobro de cuenta ' ||
                                           v_nro_cuenta;
                r_gmovi.estado          := 'N';
                r_gmovi.reversado       := 'N';
                --Entra el rubro contable
                r_gmovi.cod_rubro     := v_cod_rubro;
                r_gmovi.tip_mov_rubro := 'D';
                pag_gen.pr_ins_ge_movimiento(r_gmovi);
              ELSIF v_cta_bancaria is not null then

                IF p_tip_pago = '2' THEN
                  IF p_cod_banco IS NOT NULL THEN
                    BEGIN
                      SELECT to_char('10' || substr(p_cod_banco, 2, 3))
                        INTO v_cod_bco_central
                        FROM dual;
                    EXCEPTION
                      WHEN no_data_found THEN
                        v_cod_bco_central := null;
                    END;
                    --Obtener el codigo de banco, ya que no coincide con el listado del BCP.
                    BEGIN
                      SELECT cod_banco, descripcion
                        INTO v_cod_banco, v_des_banco
                        FROM ge_bancos
                       WHERE cod_bco_central = v_cod_bco_central;
                    EXCEPTION
                      WHEN no_data_found THEN
                        v_cod_retorno := pag_ser.v_bco_incorrecto;
                        v_des_retorno := 'Banco incorrecto.';
                    END;

                    --Verifico si ya existe un cobro con el mismo cheque
                    BEGIN
                      v_exist_chq := NULL;
                      SELECT 'S'
                        INTO v_exist_chq
                        FROM cc_che_enviados
                       WHERE cod_banco = p_cod_banco
                         AND nro_cheque = p_nro_cheque
                         AND nro_cuenta = p_nro_cuenta
                         AND fecha = v_fec_actual;
                    EXCEPTION
                      WHEN OTHERS THEN
                        BEGIN
                          v_exist_chq_c := NULL;
                          SELECT 'S'
                            INTO v_exist_chq_c
                            FROM ge_che_custodias
                           WHERE cod_banco = p_cod_banco
                             AND nro_cheque = p_nro_cheque
                             AND nro_referencia = p_nro_cuenta
                             AND estado NOT IN ('E', 'R');
                        EXCEPTION
                          WHEN OTHERS THEN
                            NULL;
                        END;
                    END;

                    IF v_exist_chq IS NOT NULL THEN
                      v_cod_retorno := pag_ser.v_che_existente;
                      v_des_retorno := 'Cheque utilizado en la oper.';
                    END IF;
                    IF v_exist_chq_c IS NOT NULL THEN
                      v_cod_retorno := pag_ser.v_che_rel_cuota;
                      v_des_retorno := 'Cheque ya relacionado a cuota.';
                    END IF;
                    -- verificar si el cheque no fue ya ingresado en el detalle de los cheques
                    begin
                      select count(1)
                        into v_existe
                        from ge_cheques_det
                       where (nro_cuenta = v_nro_cuenta or
                             nro_cuenta is null)
                         and nro_cheque = p_nro_cheque
                         and cod_banco = p_cod_banco
                         and fec_ingreso >= v_fec_actual;
                      If v_existe > 0 then
                        v_cod_retorno := pag_ser.v_che_detallado;
                        v_des_retorno := 'Cheque ya ingresado.';
                      End if;
                    exception
                      when no_data_found then
                        null;
                    end;
                    v_dat_banco := ' Banco : ' || v_des_banco ||
                                   ' Nro Cheque ' || p_nro_cheque;
                  END IF;
                  ------------------------------------------
                  v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;

                  pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(v_cta_bancaria),
                                           'D');

                  pag_cta.pr_act_operacion(v_cta_bancaria,
                                           v_hor_cobro, --HORA
                                           'C',
                                           r_ctapre.cod_moneda,
                                           v_importe,
                                           v_cod_tra_padre, --COD_TRA_PADRE
                                           602,
                                           v_nro_documento,
                                           NULL, --COTIZACION
                                           v_cod_ofi_origen, --cod_ofi_origen
                                           v_cod_modulo, --cod_mod_padre
                                           v_cod_modalidad, --cod_mad_padre
                                           null, --cod_tasa
                                           null, --val_tasa
                                           'Cobro de cuenta ' ||
                                           v_nro_cuenta || v_dat_banco,
                                           'S', --emi_aviso
                                           v_nro_secuencia,
                                           v_fec_actual);

                  If pag_cta.fu_obt_cod_error() <> 0 then
                    v_cod_retorno := v_err_proceso;
                    v_des_retorno := 'Al hace el débito en la cuenta bancaria.';
                  End if;
                  ------------------------------------------
                END IF;

                /* v_nro_secuencia  := nvl(v_nro_secuencia, 0) + 1;

                pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(v_cta_bancaria), 'D');

                pag_cta.pr_act_operacion(v_cta_bancaria,
                                         v_hor_cobro, --HORA
                                         'C',
                                         r_ctapre.cod_moneda,
                                         v_importe,
                                         v_cod_tra_padre,--COD_TRA_PADRE
                                         602,
                                         v_nro_documento,
                                         NULL, --COTIZACION
                                         v_cod_ofi_origen, --cod_ofi_origen
                                         v_cod_modulo, --cod_mod_padre
                                         v_cod_modalidad, --cod_mad_padre
                                         null, --cod_tasa
                                         null, --val_tasa
                                         'Cobro de cuenta '||v_nro_cuenta || v_dat_banco,
                                         'S', --emi_aviso
                                         v_nro_secuencia,
                                         v_fec_actual);

                If pag_cta.fu_obt_cod_error() <> 0 then
                   v_cod_retorno := v_err_proceso;
                   v_des_retorno := 'Al hace el débito en la cuenta bancaria.';
                End if;*/ --se mueve arriba del if nr

              ELSE
                -- genero movimiento por el cobro en efectivo --
                IF p_tip_pago = '1' THEN
                  --Efectivo.
                  v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
                  r_gmovi.cod_usuario     := v_cod_usuario;
                  r_gmovi.hora            := v_hor_cobro;
                  r_gmovi.fecha           := v_fec_actual;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.cod_modulo      := v_cod_modulo;
                  r_gmovi.cod_modalidad   := v_cod_modalidad;
                  r_gmovi.cod_oficina     := v_cod_ofi_origen;
                  r_gmovi.cod_moneda      := r_ctapre.cod_moneda;
                  r_gmovi.fec_valor       := v_fec_actual;
                  r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                  r_gmovi.cod_mod_padre   := v_cod_modulo;
                  r_gmovi.cod_mad_padre   := v_cod_modalidad;
                  r_gmovi.nro_caja        := NULL;
                  r_gmovi.cod_transaccion := 740;
                  r_gmovi.monto           := v_importe;
                  r_gmovi.nro_documento   := v_nro_documento;
                  r_gmovi.nro_documento2  := NULL;
                  r_gmovi.nro_documento3  := p_nro_cuota;
                  r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
                  r_gmovi.emi_aviso       := 'S';
                  r_gmovi.concepto        := 'Cobro Prest :' ||
                                             v_nro_cuenta;
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_rubro       := NULL;
                  r_gmovi.nro_cuenta      := NULL;
                  r_gmovi.tip_mov_rubro   := 'D';
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
                ELSIF p_tip_pago = '2' THEN
                  IF p_cod_banco IS NOT NULL THEN
                    BEGIN
                      SELECT to_char('10' || substr(p_cod_banco, 2, 3))
                        INTO v_cod_bco_central
                        FROM dual;
                    EXCEPTION
                      WHEN no_data_found THEN
                        v_cod_bco_central := null;
                    END;
                    --Obtener el codigo de banco, ya que no coincide con el listado del BCP.
                    BEGIN
                      SELECT cod_banco
                        INTO v_cod_banco
                        FROM ge_bancos
                       WHERE cod_bco_central = v_cod_bco_central;
                    EXCEPTION
                      WHEN no_data_found THEN
                        v_cod_retorno := pag_ser.v_bco_incorrecto;
                        v_des_retorno := 'Banco incorrecto.';
                    END;

                    --Verifico si ya existe un cobro con el mismo cheque
                    BEGIN
                      v_exist_chq := NULL;
                      SELECT 'S'
                        INTO v_exist_chq
                        FROM cc_che_enviados
                       WHERE cod_banco = p_cod_banco
                         AND nro_cheque = p_nro_cheque
                         AND nro_cuenta = p_nro_cuenta
                         AND fecha = v_fec_actual;
                    EXCEPTION
                      WHEN OTHERS THEN
                        BEGIN
                          v_exist_chq_c := NULL;
                          SELECT 'S'
                            INTO v_exist_chq_c
                            FROM ge_che_custodias
                           WHERE cod_banco = p_cod_banco
                             AND nro_cheque = p_nro_cheque
                             AND nro_referencia = p_nro_cuenta
                             AND estado NOT IN ('E', 'R');
                        EXCEPTION
                          WHEN OTHERS THEN
                            NULL;
                        END;
                    END;

                    IF v_exist_chq IS NOT NULL THEN
                      v_cod_retorno := pag_ser.v_che_existente;
                      v_des_retorno := 'Cheque utilizado en la oper.';
                    END IF;
                    IF v_exist_chq_c IS NOT NULL THEN
                      v_cod_retorno := pag_ser.v_che_rel_cuota;
                      v_des_retorno := 'Cheque ya relacionado a cuota.';
                    END IF;
                    -- verificar si el cheque no fue ya ingresado en el detalle de los cheques
                    begin
                      select count(1)
                        into v_existe
                        from ge_cheques_det
                       where (nro_cuenta = v_nro_cuenta or
                             nro_cuenta is null)
                         and nro_cheque = p_nro_cheque
                         and cod_banco = p_cod_banco
                         and fec_ingreso >= v_fec_actual;
                      If v_existe > 0 then
                        v_cod_retorno := pag_ser.v_che_detallado;
                        v_des_retorno := 'Cheque ya ingresado.';
                      End if;
                    exception
                      when no_data_found then
                        null;
                    end;
                  END IF;

                  IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.cod_usuario     := v_cod_usuario;
                    r_gmovi.hora            := v_hor_cobro;
                    r_gmovi.fecha           := v_fec_actual;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.cod_modulo      := v_cod_modulo;
                    r_gmovi.cod_modalidad   := v_cod_modalidad;
                    r_gmovi.cod_oficina     := v_cod_ofi_origen;
                    r_gmovi.cod_moneda      := r_ctapre.cod_moneda;
                    r_gmovi.fec_valor       := v_fec_actual;
                    r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                    r_gmovi.cod_mod_padre   := v_cod_modulo;
                    r_gmovi.cod_mad_padre   := v_cod_modalidad;
                    r_gmovi.nro_caja        := NULL;
                    r_gmovi.cod_transaccion := 607; --- Cheques
                    r_gmovi.monto           := v_importe;
                    r_gmovi.nro_documento   := v_nro_documento;
                    r_gmovi.nro_documento2  := p_nro_cheque;
                    r_gmovi.nro_documento3  := p_nro_cuota;
                    r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
                    r_gmovi.emi_aviso       := 'S';
                    r_gmovi.concepto        := 'Cobro Prest :' ||
                                               v_nro_cuenta || ' Banco : ' ||
                                               v_cod_banco;
                    r_gmovi.estado          := 'N';
                    r_gmovi.reversado       := 'N';
                    r_gmovi.cod_rubro       := NULL;
                    r_gmovi.nro_cuenta      := NULL;
                    r_gmovi.tip_mov_rubro   := NULL;
                    -- Recuperar datos de la retencion
                    pag_cta.pr_obt_retencion(v_fec_actual,
                                             v_nro_cuenta,
                                             v_cod_modulo,
                                             v_cod_modalidad,
                                             607,
                                             r_ctapre.cod_moneda,
                                             r_gmovi.cod_retencion,
                                             r_gmovi.fec_fin_retencion);
                    pag_gen.pr_ins_ge_movimiento(r_gmovi);
                    --Genero el registro en detalle de cheques
                    begin
                      insert into ge_cheques_det
                        (cod_banco,
                         nro_cheque,
                         cta_libradora,
                         cod_moneda,
                         monto,
                         nro_cuenta,
                         nro_cuota,
                         estado,
                         fec_ingreso,
                         nro_documento,
                         cod_ofi_camara,
                         cod_retencion,
                         cod_usuario,
                         hora,
                         fec_deposito,
                         nro_caja)
                      values
                        (to_number(p_cod_banco),
                         to_number(p_nro_cheque),
                         0, ---- todavia no se usa p_cta_libradora,
                         r_ctapre.cod_moneda,
                         v_importe,
                         v_nro_cuenta,
                         null,
                         'I', --ingresado
                         v_fec_actual,
                         to_number(v_nro_documento),
                         v_cod_ofi_origen,
                         r_gmovi.cod_retencion,
                         v_cod_usuario,
                         v_hor_cobro,
                         r_gmovi.fec_fin_retencion,
                         v_nro_caja);

                      --Actualizo el control de caja
                      update cj_controles
                         set det_che_otr_bco = nvl(det_che_otr_bco, 0) +
                                               nvl(v_importe, 0),
                             estado          = 1 -- abierto
                       where nro_caja = to_number(v_nro_caja)
                         and cod_moneda = r_ctapre.cod_moneda
                         and fecha = v_fec_actual;
                      --Genero el movimiento por el  cheque
                      --v_hor_cobro := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
                      insert into cj_movimientos
                        (fecha,
                         hora,
                         cod_usuario,
                         nro_secuencia,
                         cod_tra_padre,
                         cod_mod_padre,
                         cod_mad_padre,
                         cod_oficina,
                         cod_moneda,
                         nro_caja,
                         nro_documento,
                         nro_cuenta,
                         monto,
                         tip_monto,
                         tipo,
                         nro_doc_referencia)
                      values
                        (v_fec_actual,
                         v_hor_cobro,
                         v_cod_usuario,
                         1, -- secuencia 1
                         355,
                         9,
                         91,
                         v_cod_ofi_origen,
                         r_ctapre.cod_moneda,
                         to_number(v_nro_caja),
                         p_nro_cheque,
                         v_nro_cuenta,
                         v_importe,
                         'O' /* cheq.otros bcos */,
                         v_tipo,
                         v_nro_documento); /* no es debito ni credito */
                    exception
                      when others then
                        v_cod_retorno := pag_ser.v_error;
                        v_des_retorno := 'Ins.cheques-' ||
                                         substr(sqlerrm, 1, 15);
                    end;

                  END IF;
                END IF;
              END IF;

              --
              BEGIN
                SELECT c.nro_documento,
                       SUM(nvl(a.mto_capital, 0) + nvl(a.mto_interes, 0) +
                           nvl(a.mto_int_documentado, 0)),
                       SUM(nvl(a.mto_int_moratorio, 0)),
                       SUM(nvl(a.mto_int_mor_interes, 0)),
                       SUM(nvl(a.mto_int_mor_adelantado, 0)),
                       SUM(nvl(a.mto_int_punitorio, 0)),
                       SUM(nvl(a.mto_impuesto, 0)),
                       SUM(nvl(a.mto_cargo, 0) - nvl(a.mto_cargo_iva, 0)),
                       SUM(nvl(a.mto_cargo_iva, 0)),
                       SUM(nvl(a.mto_capital, 0)),
                       SUM((nvl(a.mto_interes, 0) +
                           nvl(a.mto_int_documentado, 0))),
                       SUM(nvl(a.sal_capital_cuo, 0) -
                           nvl(a.mto_capital, 0)),
                       SUM((nvl(a.sal_interes_cuo, 0) +
                           nvl(a.sal_int_documentado, 0)) -
                           (nvl(a.mto_interes, 0) +
                           nvl(a.mto_int_documentado, 0))),
                       SUM(nvl(a.mto_int_descontado, 0))
                  INTO v_nro_doc_cliente,
                       v_cuota,
                       v_int_mor_cap,
                       v_int_mor_int,
                       v_int_mor_ade,
                       v_int_punitorio,
                       v_impuesto,
                       v_cargo,
                       v_iva,
                       v_mto_capital,
                       v_mto_interes,
                       v_saldo_capital,
                       v_saldo_interes,
                       v_mto_descontado
                  FROM ba_personas       c,
                       ge_cta_clientes   b,
                       pr_cobros         a,
                       pr_cta_prestamos  p,
                       ba_tip_documentos d
                 WHERE a.nro_cuenta = b.nro_cuenta
                   AND p.nro_cuenta = a.nro_cuenta
                   AND b.relacion = 'P'
                   AND c.cod_persona = b.cod_persona
                   AND a.nro_cuenta = p_nro_cuenta
                   AND d.cod_tip_documento = c.cod_tip_documento
                   AND a.fecha = v_fec_actual
                   AND a.hora = v_hor_cobro
                 GROUP BY c.nro_documento;
              EXCEPTION
                WHEN OTHERS THEN
                  v_cod_retorno := pag_ser.v_err_proceso;
                  v_des_retorno := 'Error en el proceso.';
              END;
            END IF;
            --
          END IF;
        END IF;
      END IF;
    END IF;

    if fug_obt_pardinamico('PRE_OBT_PTO_COBRANZA') = 'S' then
      /*v_cadena := rpad(p_cod_servicio, 5, ' ') || lpad(p_tip_transaccion, 2, '0') ||
      rpad(v_cod_retorno, 3, ' ') || rpad(v_des_retorno, 30, ' ') || lpad(v_nro_documento, 15, '0')||
      lpad(v_nro_doc_cliente, 15, '0')||lf_for_money(v_mto_capital, 16,p_cod_moneda) || lf_for_money(v_mto_interes, 16,p_cod_moneda) ||
      lf_for_money((v_int_mor_cap+v_int_mor_int+v_int_mor_ade), 16,p_cod_moneda) || lf_for_money(v_int_punitorio, 16,p_cod_moneda) ||
      lf_for_money((v_cargo+v_iva), 16,p_cod_moneda) || lf_for_money(v_impuesto, 16,p_cod_moneda) || lf_for_money(v_iva5, 16,p_cod_moneda) ||
      lf_for_money(v_iva_devuelto, 16,p_cod_moneda) || lf_for_money(v_importe, 16,p_cod_moneda);*/
      v_cadena := v_des_retorno; --nrecalde
      commit;
    else
      /*v_cadena := rpad(p_cod_servicio, 5, ' ') || lpad(p_tip_transaccion, 2, '0') ||
      rpad(v_cod_retorno, 3, ' ') || rpad(v_des_retorno, 30, ' ');*/
      v_cadena := v_cod_retorno || '-' || v_des_retorno;
    end if;
    if v_des_retorno = 'OK' then
      v_cadena := v_des_retorno;
    end if;
    RETURN v_cadena;
  END fu_cob_prestamo;

FUNCTION fu_obt_ser_moneda(p_codigo IN NUMBER)
   RETURN VARCHAR2 IS
BEGIN
   CASE p_codigo
      WHEN 1 THEN -- GS
         RETURN v_cod_mon_local;
      WHEN 5 THEN -- USD
         RETURN pag_gen.fu_obt_mon_fuerte();
      ELSE -- otros codigos, no habilitado
         RETURN NULL;
   END CASE;
END;

FUNCTION fu_obt_cta_credito(p_proveedor       IN NUMBER,
                            p_moneda          IN NUMBER,
                            p_nro_cta_credito OUT VARCHAR2,
                            p_cod_moneda      OUT VARCHAR2) RETURN NUMBER IS
BEGIN
   p_cod_moneda := fu_obt_ser_moneda(p_moneda);
   IF p_moneda IS NULL THEN
      RETURN -1;
   END IF;
   IF p_proveedor = 1 THEN -- netel
      p_nro_cta_credito := fug_obt_pardinamico('NRO_CTA_CRE_SER_NETEL', NULL, NULL, p_cod_moneda);
   ELSIF p_proveedor = 0 THEN -- pronet
      p_nro_cta_credito := fug_obt_pardinamico('NRO_CTA_CRE_SERVICIOS');
   ELSE
      RETURN -1;
   END IF;

   RETURN 0;
EXCEPTION
   WHEN OTHERS THEN
      RETURN -1;
END;

FUNCTION fu_obt_tra_padre(p_proveedor IN NUMBER) RETURN NUMBER IS
   v_cod_tra_padre ge_transacciones.cod_transaccion%TYPE;
BEGIN
   CASE p_proveedor
      WHEN 0 THEN -- pronet
         v_cod_tra_padre := 485;
      WHEN 1 THEN -- netel
         v_cod_tra_padre := 486;
      WHEN 2 THEN -- SET
         v_cod_tra_padre := 487;
      ELSE -- proveedor desconocido
         v_cod_tra_padre := NULL;
   END CASE;

   RETURN v_cod_tra_padre;
END;

FUNCTION fu_PagoServicios(p_cod_persona     IN VARCHAR2,
                          p_cod_empresa     IN VARCHAR2,
                          p_sesion          IN VARCHAR2,
                          p_servicio        IN NUMBER,
                          p_cuenta          IN VARCHAR2,
                          p_nro_tran        VARCHAR2,
                          p_nro_lote        VARCHAR2,
                          p_nro_ip          VARCHAR2,
                          p_terminal        VARCHAR2,
                          p_moneda          NUMBER,
                          p_imp_tran        NUMBER,
                          p_imp_comision    NUMBER,
                          p_imp_mora        NUMBER,
                          p_imp_interes     NUMBER,
                          p_cod_ws_servicio IN VARCHAR2,
                          p_proveedor       IN NUMBER,
                          p_mto_debito      IN NUMBER,
                          p_cot_debito      IN NUMBER,
                          p_cot_credito     IN NUMBER,
                          p_nro_documento   IN NUMBER,
                          p_ref_pago        IN VARCHAR2) RETURN NUMBER IS
   v_nro_cuenta       ge_movimientos.nro_cuenta%TYPE;
   v_cod_tra_padre    ge_movimientos.cod_tra_padre%TYPE;
   v_cod_ofi_origen   ge_movimientos.cod_oficina%TYPE;
   v_cod_mod_padre    ge_movimientos.cod_modulo%TYPE;
   v_cod_mad_padre    ge_movimientos.cod_modalidad%TYPE;
   v_sal_disponible   ge_movimientos.monto%TYPE;
   v_nro_operacion    ge_movimientos.nro_documento%TYPE;
   v_mto_credito      ge_movimientos.monto%TYPE;
   v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
   v_nro_cta_credito  ge_movimientos.nro_cuenta%TYPE;
   v_nvo_estado       VARCHAR2(1);
   --   v_msj_respuesta   VARCHAR2(250);
   v_cod_respuesta    NUMBER(2);
   v_procesa          VARCHAR2(1);
   v_cod_mon_servicio ba_monedas.cod_moneda%TYPE := NULL;
   v_mto_debito       ge_movimientos.monto%TYPE := p_mto_debito;
   v_cod_mon_debito   ba_monedas.cod_moneda%TYPE := NULL;
   v_cod_mod_debito   ge_transacciones.cod_modulo%TYPE := NULL;
   v_cod_mad_debito   ge_transacciones.cod_modalidad%TYPE := NULL;
   v_cod_mon_credito  ba_monedas.cod_moneda%TYPE := NULL;
   v_cotizacion       bw_pag_servicios.cotizacion%TYPE := NULL;
   v_cot_debito       ge_movimientos.cotizacion%TYPE := p_cot_debito;
   v_cot_credito      ge_movimientos.cotizacion%TYPE := p_cot_credito;
   v_mto_equ_local    ge_movimientos.mto_equ_local%TYPE;
   v_cta_principal    ge_cta_clientes.cod_persona%TYPE;
   v_cod_res          VARCHAR2(2); -- para limite global de operaciones
   v_ret              NUMBER(3);
   v_ref_pago         bw_pag_servicios.ref_pago%TYPE := p_ref_pago;
   v_tag              VARCHAR2(20);
   v_cod_tip_mensaje  bw_tip_mensajes.cod_tip_mensaje%TYPE;
   v_abre_oper        ba_cod_referencias.abreviatura%TYPE := NULL;
   v_servicio         VARCHAR2(20) := p_servicio;
   v_proveedor        VARCHAR2(10) := p_proveedor;
BEGIN
   v_cod_respuesta   := 0;
   --   v_msj_respuesta   := '';
   v_nro_cuenta      := p_cuenta;
   v_cod_transaccion := 503; --débito en caja de ahorros
   v_cod_tra_padre   := fu_obt_tra_padre(p_proveedor);
   v_cod_mod_padre   := 9;
   v_cod_mad_padre   := 91;
   -- OMM 11/02/2011 Para poder asignar otra cuenta.
   v_cod_ofi_origen  := 31; -- Oficina origen para realizar interoficinas
   v_mto_credito     := nvl(p_imp_tran, 0);
   v_nro_operacion   := p_nro_documento;
   /********/

   BEGIN
      PRE_INI_APLICACION;
      PAE_CNF.G_COD_MODULO := 1;
   END;
   v_fec_actual  := pag_cal.fu_obt_fec_actual(3);          -- fecha de hoy
   v_fec_valor   := v_fec_actual;
   v_hor_actual  := to_char(sysdate,'HH24:MI:SS');   -- Hora actual

   IF fu_obt_cta_credito(p_proveedor, p_moneda, v_nro_cta_credito, v_cod_mon_servicio) <> 0 THEN
      v_msj_respuesta := 'moneda de servicio no encontrada';
      RETURN 2; -- transaccion no permitida, moneda de servicio no habilitado
   END IF;

   lp_ver_horario;
   IF pag_ser.v_cod_respuesta <> 0 THEN
      RETURN 12; --Error de horario, sistema en cierre
   END IF;

   -- Obtiene datos de la cuenta débito
   pag_cta.pr_obt_cuenta(v_nro_cuenta);
   IF pag_cta.fu_obt_cod_error() <> 0 THEN
      v_msj_respuesta := substr(pag_cta.g_msj_error, 1, 200);
      RETURN 1; --no se pudo validar la cuenta de debito
   ELSE
      v_cod_mon_debito := pag_cta.g_ctas.cod_moneda;
      v_cod_mod_debito := pag_cta.g_ctas.cod_modulo;
      v_cod_mad_debito := pag_cta.g_ctas.cod_modalidad;

      SELECT cod_persona
        INTO v_cta_principal
        FROM ge_cta_clientes
       WHERE nro_cuenta = v_nro_cuenta
         AND relacion = 'P'
         AND cod_modulo IN (3,4)
         AND cod_modalidad IN (31, 41);
   END IF;

   -- Obtiene datos de la cuenta crédito
   pag_cta.pr_obt_cuenta(v_nro_cta_credito);
   IF pag_cta.fu_obt_cod_error() <> 0 THEN
      v_msj_respuesta := substr(pag_cta.g_msj_error, 1, 200);
      RETURN 7; --Error en credito
   ELSE
      v_cod_mon_credito := pag_cta.g_ctas.cod_moneda;
   END IF;

   IF v_cod_mon_credito <> v_cod_mon_servicio THEN
      v_msj_respuesta := 'moneda servicio <> moneda cta. credito';
      RETURN 7; --Error en credito
   END IF;

   -- monedas diferentes
   IF v_cod_mon_credito <> v_cod_mon_debito THEN
      IF v_cod_mon_debito <> v_cod_mon_local THEN
         v_cotizacion := v_cot_debito;
      ELSE
         v_cotizacion := v_cot_credito;
      END IF;
   END IF;

   -- OMM 24/01/2011 En BBVA solo se paga con Cuentas en moneda GS
   IF pag_cta.fu_ver_tra_prohibida(v_nro_cuenta, v_cod_transaccion, v_cod_mod_debito /*pag_cta.g_ctas.cod_modulo*/, v_cod_mad_debito /*pag_cta.g_ctas.cod_modalidad*/) = 'S' THEN
      v_msj_respuesta := 'fu_ver_tra_prohibida';
      RETURN 2;
   ELSE
      /* OMM 25/01/2011 Se modifico para tener en cuenta el modulo y modalidad de la cuenta */
      pag_cta.pr_ver_operacion(v_nro_cuenta,
                               v_cod_tra_padre,
                               v_cod_mod_padre,
                               v_cod_mad_padre,
                               'D',
                               v_cod_mon_debito, --pag_cta.g_ctas.cod_moneda
                               v_mto_debito,
                               v_cod_ofi_origen,
                               v_cod_mod_debito, --pag_cta.g_ctas.cod_modulo
                               v_cod_mad_debito, --pag_cta.g_ctas.cod_modalidad
                               v_nvo_estado,
                               v_sal_disponible,
                               v_procesa,
                               v_cod_transaccion);

      IF v_procesa = 'N' THEN
         v_msj_respuesta := substr(pag_cta.g_msj_error, 1, 200);
         -- no se puede debitar
         IF instr(upper(pag_cta.G_MSJ_ERROR), 'INSUFIC') > 0 THEN
            -- saldo insuficiente
            RETURN 3; -- saldo insuficiente
         ELSE
            RETURN 4; -- error en pag cta
         END IF;
      ELSE

         lp_ver_horario;

         -- se controla la transacción
         IF lf_ver_transaccion(v_nro_cuenta, v_mto_debito, p_servicio) = 'S' THEN
            RETURN 5; --Transaccion repetida
         END IF;

         -- 07/05/2012 : se agrega control de limite
         IF v_cod_respuesta <> -1 THEN
           -- para servicios criticos
            v_abre_oper := paw_uti.fu_obt_abr_refcodes('SERVICIOS_CRITICOS', v_servicio, p_proveedor);
            IF v_abre_oper = v_servicio THEN
               v_cod_tip_mensaje := '091';
               v_tag := 'COD_WS_CRI:'; -- para diferenciar limites en los movimientos
            ELSE
               v_cod_tip_mensaje := '088';
               v_tag := 'COD_WS:';
            END IF;
            v_cod_res := paw_bce.fu_obt_limite(v_cod_tip_mensaje,
                                               p_cod_persona, -- cod_persona se saca de bw_sessiones
                                               v_nro_cuenta,
                                               v_cod_mon_debito, --pag_cta.g_ctas.cod_moneda
                                               503,
                                               v_cod_tra_padre,
                                               v_mto_debito,
                                               'C',
                                               null,
                                               null,
                                               null,
                                               1,
                                               p_cod_empresa);
         END IF;

         IF v_cod_res IN ('-2', '-1') THEN
            RETURN 6; --Error de limites
         END IF;
         -- fin limite operativo

         IF v_cod_respuesta <> -1 AND v_cod_respuesta <> -2 THEN
            v_nro_secuencia := 0;

            -- se puede registrar
            pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                     v_fec_valor,
                                     v_cod_tra_padre,
                                     'N',
                                     'N',
                                     v_nro_secuencia,
                                     NULL,
                                     v_cod_ofi_origen,
                                     v_cod_mod_padre,
                                     v_cod_mad_padre);

            v_mto_equ_local := NULL;
            IF v_cod_mon_debito <> v_cod_mon_local THEN
               IF v_cod_mon_credito = v_cod_mon_local THEN
                  v_mto_equ_local := v_mto_credito ;
               ELSE
                  v_mto_equ_local := NULL;
               END IF;
            END IF;
            v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');  -- DDSI-212 -- 2017/12
            -- Registrar movimiento de debito al cliente
            pag_cta.PR_ACT_OPERACION(v_nro_cuenta,
                                     v_hor_actual,
                                     'D',
                                     v_cod_mon_debito, --pag_cta.g_ctas.cod_moneda
                                     v_mto_debito,
                                     v_cod_tra_padre,
                                     v_cod_transaccion,
                                     v_nro_operacion,
                                     v_cot_debito,
                                     v_cod_ofi_origen,
                                     v_cod_mod_padre,
                                     v_cod_mad_padre,
                                     NULL, --codigo tasa
                                     NULL, --valor tasa
                                     'Cta:' || v_nro_cuenta || '-' || v_tag || p_cod_ws_servicio || ' via YG',
                                     'N', -- emitir aviso
                                     v_nro_secuencia,
                                     v_fec_valor,
                                     NULL, -- codigo banco
                                     NULL, -- codigo causa
                                     v_mto_equ_local);
            IF nvl(pag_cta.g_cod_error,0) <> 0 THEN
               v_msj_respuesta := substr(pag_cta.g_msj_error, 1, 200);
               RETURN 4; -- no se pudo debitar
            END IF;

            -- Inserto movimiento para crédito cuenta contable
            IF v_cod_mon_credito <> v_cod_mon_local THEN
               IF v_cod_mon_debito = v_cod_mon_local THEN
                  v_mto_equ_local := v_mto_debito ;
               ELSE
                  v_mto_equ_local := NULL;
               END IF;
            END IF;
         if (pag_bat.fu_act_sal_bat_estado(p_proveedor) = 'S') then
      v_nro_secuencia := v_nro_secuencia+1;
            pag_bat.PR_ACT_OPERACION(v_nro_cta_credito,
                                     v_fec_actual, -- DDSI-212 -- 2017/12
                                     v_hor_actual,
                                     'C',
                                     v_cod_mon_credito, --pag_cta.g_ctas.cod_moneda
                                     v_mto_credito, --v_monto
                                     v_cod_tra_padre,
                                     602,
                                     v_nro_operacion,
                                     v_cot_credito,
                                     v_cod_ofi_origen,
                                     v_cod_mod_padre,
                                     v_cod_mad_padre,
                                     NULL, -- codigo tasa
                                     NULL, -- valor tasa
                                     'Cta:' || v_nro_cuenta || '-' || 'COD_WS:' || p_cod_ws_servicio || ' via YG',
                                     'N', -- emitir aviso
                                     v_nro_secuencia,
                                     v_fec_valor,
                                     NULL, --codigo banco
                                     NULL, --codigo causa
                                     v_mto_equ_local,'N');
         else
            pag_cta.PR_ACT_OPERACION(v_nro_cta_credito,
                                     v_hor_actual,
                                     'C',
                                     v_cod_mon_credito, --pag_cta.g_ctas.cod_moneda
                                     v_mto_credito, --v_monto
                                     v_cod_tra_padre,
                                     602,
                                     v_nro_operacion,
                                     v_cot_credito,
                                     v_cod_ofi_origen,
                                     v_cod_mod_padre,
                                     v_cod_mad_padre,
                                     NULL, -- codigo tasa
                                     NULL, -- valor tasa
                                     'Cta:' || v_nro_cuenta || '-' || 'COD_WS:' || p_cod_ws_servicio || ' via YG',
                                     'N', -- emitir aviso
                                     v_nro_secuencia,
                                     v_fec_valor,
                                     NULL, --codigo banco
                                     NULL, --codigo causa
                                     v_mto_equ_local);
         end if;
            IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
               v_msj_respuesta := substr(pag_cta.g_msj_error, 1, 200);
               RETURN 8; --Error en credito
            END IF;
            BEGIN
               IF v_cod_mon_credito <> v_cod_mon_debito THEN
                  IF v_cod_mon_credito = v_cod_mon_local THEN
                     v_mto_equ_local := v_mto_credito;
                  ELSIF v_cod_mon_debito = v_cod_mon_local THEN
                     v_mto_equ_local := v_mto_debito;
                  ELSE
                     v_mto_equ_local := NULL;
                  END IF;
               END IF;
               INSERT INTO bw_pag_servicios
                  (nro_cuenta, cod_servicio, fecha, hora, nro_transaccion, nro_lote, ip_usuario, terminal, cod_moneda, mto_transaccion,
                   mto_comision, mto_mora, mto_interes, reversado, mto_debito, cod_mon_servicio, nro_sesion, cod_ws_servicios, cod_proveedor,
                   nro_documento, mto_equ_local, cotizacion, cod_mon_debito, ref_pago)
               VALUES
                  (v_nro_cuenta, p_servicio, v_fec_actual, v_hor_actual, p_nro_tran, p_nro_lote, p_nro_ip, p_terminal, v_cod_mon_credito, --pag_gen.fu_obt_mon_local
                   v_mto_credito, p_imp_comision, p_imp_mora, p_imp_interes, 'N', v_mto_debito/*v_monto*/, p_moneda, p_sesion, p_cod_ws_servicio, p_proveedor,
                   v_nro_operacion, v_mto_equ_local, v_cotizacion, v_cod_mon_debito, v_ref_pago);
         BEGIN
            v_ret:=PAW_not.fu_not_pag_servicios(v_nro_cuenta, v_mto_credito, v_cod_mon_credito, 'P', SYSDATE);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
            EXCEPTION
               WHEN OTHERS THEN
                  v_msj_respuesta := substr(sqlerrm, 1, 200);
                  RETURN 11;
            END;
         END IF;
      END IF;
   END IF;

   /********/
   IF v_cod_respuesta = 0 THEN
      RETURN 0;
   ELSE
      RETURN 10;
   END IF;

EXCEPTION
   WHEN fin_por_error THEN
      v_msj_respuesta := substr(SQLERRM, 1, 200);
      RETURN 20;
   WHEN OTHERS THEN
      v_msj_respuesta := substr(SQLERRM, 1, 200);
      RETURN 30;
      /*ver de tener una tabla de errores o enviar los mismos por mail*/
END;

FUNCTION fu_PagoServiciosReversa(p_cod_ws_servicio  IN VARCHAR2,
                                 p_mensajeRespuesta OUT VARCHAR2,
                                 p_horario          IN VARCHAR2 DEFAULT 'S') RETURN NUMBER IS
   v_nro_cuenta ge_movimientos.nro_cuenta%TYPE;
   v_fecha      ge_movimientos.fecha%TYPE;
   v_hora       ge_movimientos.hora%TYPE;
   v_cod_usuario ge_movimientos.cod_usuario%TYPE;  -- DDSI-212 -- 2017/12
   v_horario    VARCHAR2(50);
   v_respuesta  NUMBER(3);
   v_cod_proveedor bw_pag_servicios.cod_proveedor%TYPE;
   v_cod_tra_padre ge_transacciones.cod_transaccion%TYPE := 485;
   v_nro_lote   bw_pag_servicios.nro_lote%TYPE;
   v_nro_transaccion bw_pag_servicios.nro_transaccion%TYPE;
   v_monto    bw_pag_servicios.mto_transaccion%TYPE;
   v_cod_moneda bw_pag_servicios.cod_moneda%type;
   v_nro_documento   bw_pag_servicios.nro_documento%type;
   v_concepto   VARCHAR2(100) := NULL;
   v_ret        NUMBER(3):=0;
   v_ruc         ge_set_pagos.ruc%TYPE;
   v_nro_boleta  ge_set_pagos.nro_boleta%TYPE;
   v_cta_bcp     ge_set_impuestos.cod_cuenta%TYPE;
   v_descripcion ge_cob_ser_parametros.descripcion%TYPE;
   v_res        NUMBER(3):=0;
BEGIN

   v_respuesta := 0;
   p_mensajeRespuesta := 'OK';

   BEGIN
      PRE_INI_APLICACION;
      PAE_CNF.G_COD_MODULO := 1;
   END;

   BEGIN
  v_fec_actual  := pag_cal.fu_obt_fec_actual(3);          -- fecha de hoy
  v_fec_valor   := v_fec_actual;
  v_hor_actual  := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  -- DDSI-265 -- 02/2018 : Se busca una hora disponible
  v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, user, 'N' );
 /*

     SELECT a.nro_cuenta, a.fecha, a.hora
        INTO v_nro_cuenta, v_fecha, v_hora
        FROM bw_pag_servicios a
       WHERE a.nro_transaccion = p_nro_tran
         AND a.nro_lote = p_nro_lote
         AND a.reversado = 'N';
   */
   -- ajuste para autorizaciones de empresas
   SELECT s.fecha, s.hora, s.nro_cuenta, s.cod_proveedor,
          s.nro_lote, s.nro_transaccion, s.mto_debito, s.cod_moneda,
          s.nro_documento, s.usu_insercion
     INTO v_fecha, v_hora, v_nro_cuenta, v_cod_proveedor,
          v_nro_lote, v_nro_transaccion, v_monto, v_cod_moneda,
          v_nro_documento, v_cod_usuario
     FROM bw_pag_servicios s
    WHERE /*trunc(s.fec_insercion) = trunc(SYSDATE)
      AND*/ s.fec_insercion = (SELECT MAX(s.fec_insercion)
                               FROM bw_pag_servicios s
                              WHERE s.cod_ws_servicios = p_cod_ws_servicio
                                AND s.reversado = 'N'
                                /*AND trunc(s.fec_insercion) = trunc(SYSDATE)*/)
      AND s.cod_ws_servicios=p_cod_ws_servicio
      AND reversado = 'N';

   -- cambia concepto reversion para la SET
   IF v_cod_proveedor = 2 THEN
      DECLARE
         v_ruc         ge_set_pagos.ruc%TYPE;
         v_cta_bcp     ge_set_impuestos.cod_cuenta%TYPE;
         v_descripcion ge_cob_ser_parametros.descripcion%TYPE;
      BEGIN
         SELECT p.ruc, p.nro_boleta, decode(p.tip_orden, 2, '432', '460') cuenta_bcp
           INTO v_ruc, v_nro_boleta, v_cta_bcp
           FROM ge_set_pagos p
          WHERE p.cod_token = p_cod_ws_servicio
            AND p.fec_pago = v_fecha
            AND p.hora = v_hora;
         -- descripcion
         SELECT p.descripcion
           INTO v_descripcion
           FROM ge_cob_ser_parametros p
          WHERE p.cod_servicio = fug_obt_pardinamico('COD_SET_PAGO_'||v_cta_bcp);

         v_concepto := substr('Reversion. '||v_descripcion||'. Boleta: '||v_nro_boleta||', Ruc: '||v_ruc, 1, 100);
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
--   Reversión. PAGO IMPUESTO/TRIBUTOS. Boleta: 97000874684, Ruc:50025600-
   END IF;

      lp_ver_horario;
      IF nvl(p_horario, 'S') = 'S' THEN
         v_horario := (to_date(v_hor_actual, 'HH24:MI:SS') - to_date(v_hora, 'HH24:MI:SS')) * 2400;
      ELSE
         -- Es reversa del API de pagos, porque no se pudo reintentar con el proveedor,
         -- se debe reversar sin controlar el maximo tiempo
         v_horario := 0;
      END IF;
      --CLP DYDMR-5060 Octubre/2016
      IF to_date(v_hor_actual, 'HH24:MI:SS') - to_date(v_hora, 'HH24:MI:SS') <= 0 THEN
         v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      END IF;

      IF v_es_mov_noc = 'S' OR trunc(v_horario) > 2 THEN
         IF v_es_mov_noc = 'S' THEN
            -- OMM 16/02/2011 Si es movimiento nocturno
            v_respuesta := 12;
            p_mensajeRespuesta := 'Error al reversar. Sistema en cierre';
            pr_ins_rev_cobro(v_nro_lote, v_nro_transaccion);
         ELSE
            -- OMM 16/02/2011 Por que paso el tiempo maximo para reversar la operacion
            v_respuesta := 11;
            p_mensajeRespuesta := 'Error al reversar. Tiempo Maximo Superado';
         END IF;
         IF v_respuesta = 12 THEN
          --enviamos mail al cliente por reversion del pago a la SET o pago de servicio en el inicio de dia
             BEGIN
                 v_res:= fu_env_mail_pag_servicios(p_cod_ws_servicio,v_nro_cuenta,v_nro_boleta,v_fecha,'S',v_nro_transaccion);
             EXCEPTION
                WHEN OTHERS THEN
                   NULL;
             END;
          END IF;
      ELSE
         -- OMM 25/01/2011 Se busca el modulo y modalidad de la cuenta.
         pag_cta.pr_obt_cuenta(v_nro_cuenta);
         IF pag_cta.fu_obt_cod_error() <> 0 THEN
            v_cod_respuesta := -1;
            p_mensajeRespuesta := 'Error al buscar la cuenta ' || v_nro_cuenta;
            RAISE fin_por_error;
         END IF;

         v_cod_tra_padre := fu_obt_tra_padre(v_cod_proveedor);

         BEGIN
      -- DDSI-265 -- 02/2018 : Se busca una hora disponible
            v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, user, v_es_mov_noc );
            --si es en el mismo dia
            if(v_fecha=v_fec_actual and PAG_BAT.fu_act_sal_bat_estado(v_cod_proveedor) = 'S') then
                pag_bat.pr_rev_operacion(v_fecha,
                                  v_hora,
                                  v_cod_usuario,
                                  pag_cta.g_ctas.cod_modulo,
                                  pag_cta.g_ctas.cod_modalidad,
                                  v_cod_tra_padre,
                                  USER,
                                  v_hor_actual,
                                  'X',
                                  nvl(v_concepto, 'Reversión.Pag.Ser.YAG Lot:' || p_cod_ws_servicio),
                                  null,
                                  NULL,
                                  v_monto,
                                  p_cod_ws_servicio,
                                  v_nro_transaccion,
                                  v_nro_boleta);
            else
            prg_rev_operacion(v_fecha,
                              v_hora,
                                v_cod_usuario,
                              pag_cta.g_ctas.cod_modulo,
                              pag_cta.g_ctas.cod_modalidad,
                              v_cod_tra_padre,
                              USER,
                              v_hor_actual,
                              'X',
                              nvl(v_concepto, 'Reversión.Pag.Ser.YAG Lot:' || p_cod_ws_servicio),
                              NULL);
              -- actualiza a reversado el pago de servicio
            UPDATE bw_pag_servicios a
               SET a.reversado = 'S'
             WHERE a.cod_ws_servicios=p_cod_ws_servicio
               AND a.hora = v_hora
               AND a.fecha = v_fecha
               AND a.reversado = 'N';
            BEGIN
               --enviamos mail al cliente por reversion del pago a la SET o pago de servicio
               v_res:= fu_env_mail_pag_servicios(p_cod_ws_servicio,v_nro_cuenta,v_nro_boleta,v_fecha,'N',v_nro_transaccion);
            EXCEPTION
              WHEN OTHERS THEN
                 NULL;
            END;
            end if;



         BEGIN
            v_ret:=PAW_not.fu_not_pag_servicios(v_nro_cuenta, v_monto, v_cod_moneda, 'R', SYSDATE);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
         EXCEPTION
            WHEN OTHERS THEN -- fallo la reversion, se ingresa para reversar en el inicio de dia
               v_respuesta := 12;
               p_mensajeRespuesta := 'Error al reversar. Cuenta bloqueada';
               pr_ins_rev_cobro(v_nro_lote, v_nro_transaccion);
                 BEGIN
                     --enviamos mail al cliente por reversion del pago a la SET o pago de servicio en el inicio de dia
                     v_res:= fu_env_mail_pag_servicios(p_cod_ws_servicio,v_nro_cuenta,v_nro_boleta,v_fecha,'S',v_nro_transaccion);
                 EXCEPTION
                    WHEN OTHERS THEN
                       NULL;
                 END;
         END;
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         v_respuesta := -2;
         p_mensajeRespuesta := 'No se encuentra la operacion';
         RAISE fin_por_error;
      WHEN OTHERS THEN
         v_respuesta := -3;
         dbms_output.put_line(SQLERRM);
         p_mensajeRespuesta := substr(SQLERRM,0,300);
         RAISE fin_por_error;
   END;

   IF v_respuesta = 0 THEN
      RETURN v_respuesta ;
   ELSE
      RAISE fin_por_error;
   END IF;

EXCEPTION
   WHEN fin_por_error THEN
      RETURN v_respuesta;
   WHEN OTHERS THEN
      RETURN -4;
END;

 FUNCTION fu_rev_cob_prestamo(p_nro_cuenta IN pr_cuotas.nro_cuenta%TYPE,
                               p_nro_cuota  IN pr_cuotas.nro_cuota%TYPE,
                               p_importe    IN pr_cuotas.mto_capital%TYPE,
                               p_moneda     IN ba_monedas.cod_mon_bco_central%TYPE, --nr
                               --p_cod_moneda      IN pr_cta_prestamos.cod_moneda%TYPE, --nr
                               p_tip_transaccion IN bw_pag_servicios.nro_transaccion%TYPE,
                               p_cod_servicio    IN bw_pag_servicios.cod_servicio%TYPE,
                               p_cod_transaccion IN bw_pag_servicios.nro_transaccion%TYPE,
                               p_cod_tra_anular  IN bw_pag_servicios.nro_transaccion%TYPE,
                               p_pto_cobranza    IN bw_pag_servicios.pto_cobranza%TYPE default null

                               ) RETURN varchar2 IS
    v_fec_pago        DATE;
    v_fec_pago_noc    DATE;
    v_tip_transaccion VARCHAR2(2) := '04'; --Reversion.
    v_nro_cuenta      VARCHAR2(15);
    v_cod_tra_padre   ge_movimientos.cod_tra_padre%TYPE := 360;
    v_cod_usuario     pr_cobros.usu_insercion%TYPE;
    v_cod_modulo      ge_cta_clientes.cod_modulo%TYPE;
    v_cadena          VARCHAR2(5000);
    -- variables
    v_cod_moneda          VARCHAR2(1);
    v_hora                ge_movimientos.hora%TYPE;
    v_max_nro_transaccion bw_pag_servicios.nro_transaccion%TYPE;
    v_nro_transaccion     bw_pag_servicios.nro_transaccion%TYPE;
    v_nro_cuota           pr_cuotas.nro_cuota%TYPE;
    v_concepto            VARCHAR2(50);
    v_significado         ba_cod_referencias.significado%TYPE := '';
    v_nro_cuota_desde     pr_cobros.nro_cuota%TYPE;
    v_cod_transaccion     ge_transacciones.cod_transaccion%TYPE;
    v_mto_transaccion     bw_pag_servicios.mto_transaccion%TYPE;
    v_importe             NUMBER(16, 2); -- Variable para formatear el monto ingresado por el usuario.
    v_cob_nocturno        varchar2(1) := 'N';
    v_fec_proxima         date := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(3),
                                                             fug_obt_ofi_usuario(USER)); -- fecha de hoy
    v_hor_actual          varchar2(10) := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
    v_dato                number(6);
    v_mto_iva_devuelto    bw_pag_servicios.mto_iva_devuelto%TYPE;
    v_moneda              ba_monedas.cod_moneda%type; --nr
    CURSOR cur_gmovi IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_oficina,
             cod_error,
             cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             estado,
             cod_causa,
             cod_banco,
             cod_ofi_origen,
             concepto,
             cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             referencia,
             cod_persona,
             cod_sit_contable
        FROM ge_movimientos
       WHERE fecha = v_fec_pago
         AND hora = v_hora
         AND cod_usuario = v_cod_usuario
         AND reversado = 'N'
         AND (cod_transaccion NOT IN (941, 661) OR cod_transaccion IS NULL)
       ORDER BY nro_secuencia DESC;

  BEGIN
    /*v_importe := to_number(substr(lpad(p_importe, 15, '0'), 1, 13) || '.' ||
    substr(lpad(p_importe, 15, '0'), 14, 2), '9999999999999.99');*/
    v_importe   := to_number(p_importe);
    v_red_pago  := p_pto_cobranza;
    v_nro_cuota := p_nro_cuota;
    v_moneda    := it.fue_obt_mon_bcp(p_moneda); --nr
    if p_nro_cuota = 0 then
      v_nro_cuota     := null;
      v_cod_tra_padre := 359;
    end if;
    -- Recuperar la cuenta, esto es, por si se ingresa C.I. o Nro. Cuenta indistintamente
    -- como parametro.
    BEGIN
      SELECT c.nro_cuenta
        INTO v_nro_cuenta
        FROM ba_personas a, ge_cta_clientes c, pr_cta_prestamos s
       WHERE a.cod_persona = c.cod_persona
         AND c.nro_cuenta = s.nro_cuenta
         AND (c.nro_cuenta = p_nro_cuenta OR
             replace(a.nro_documento, '-', '') = p_nro_cuenta)
         AND c.relacion = 'P';
      --AND s.estado <> 'N';
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_tra_incorrecta;
        v_des_retorno := 'Cuenta inexistente.';
    END;

    BEGIN
      --- Se pide en 3 select porque trae el max hora aparte de la fecha, hay que pedir el max hora de la fecha maxima
      SELECT MAX(a.fecha)
        INTO v_fec_pago
        FROM pr_cobros a
        LEFT JOIN bw_pag_servicios b
          ON a.nro_cuenta = b.nro_cuenta
         AND a.fecha = b.fecha
         AND a.hora = b.hora
         AND a.usu_insercion = b.usu_insercion
       WHERE a.nro_cuenta = v_nro_cuenta
         AND (v_nro_cuota IS NULL or a.nro_cuota = v_nro_cuota)
         AND b.reversado = 'N';

      SELECT MAX(a.fecha)
        INTO v_fec_pago_noc
        FROM pr_cobros_noc a
        LEFT JOIN bw_pag_servicios b
          ON a.nro_cuenta = b.nro_cuenta
         AND a.fecha = b.fecha
         AND a.hora = b.hora
         AND a.usu_insercion = b.usu_insercion
       WHERE a.nro_cuenta = v_nro_cuenta
         AND (v_nro_cuota IS NULL OR
             v_nro_cuota BETWEEN a.nro_cuota_desde AND a.nro_cuota_hasta)
         AND b.reversado = 'N';

      if (v_fec_pago < v_fec_pago_noc or v_fec_pago is null) then

        SELECT MAX(hora)
          INTO v_hora
          FROM pr_cobros_noc
         WHERE nro_cuenta = v_nro_cuenta
           AND (v_nro_cuota IS NULL or
               v_nro_cuota between nro_cuota_desde and nro_cuota_hasta)
           AND fecha = v_fec_pago_noc;

        SELECT usu_insercion, nro_cuota_desde
          INTO v_cod_usuario, v_nro_cuota_desde
          FROM pr_cobros_noc
         WHERE nro_cuenta = v_nro_cuenta
           AND (v_nro_cuota IS NULL OR
               v_nro_cuota between nro_cuota_desde and nro_cuota_hasta)
           AND fecha = v_fec_pago_noc
           AND hora = v_hora;

        v_fec_pago := v_fec_pago_noc;

      elsif (v_fec_pago >= v_fec_pago_noc or v_fec_pago_noc is null) then
        SELECT MAX(hora)
          INTO v_hora
          FROM pr_cobros
         WHERE nro_cuenta = v_nro_cuenta
           AND (v_nro_cuota IS NULL OR nro_cuota = v_nro_cuota)
           AND fecha = v_fec_pago;

        SELECT usu_insercion
          INTO v_cod_usuario
          FROM pr_cobros
         WHERE nro_cuenta = v_nro_cuenta
           AND (v_nro_cuota IS NULL OR nro_cuota = v_nro_cuota)
           AND fecha = v_fec_pago
           AND hora = v_hora
           AND rownum = 1;
      end if;

    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_sin_datos;
        v_des_retorno := 'No existe pago para esa cuota';
      WHEN OTHERS THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Error en el proceso.';
    END;
    --- Verificar que la transaccion a anular corresponda a la máxima transaccion ingresada no reversada
    IF p_cod_tra_anular is not null THEN
      BEGIN
        select nvl(max(nro_transaccion), -1)
          into v_max_nro_transaccion
          from bw_pag_servicios b
         where b.nro_cuenta = v_nro_cuenta
           and b.reversado = 'N'
           and b.fecha = v_fec_pago
           and b.hora = v_hora
           and (b.pto_cobranza = p_pto_cobranza or p_pto_cobranza is null);
        IF v_max_nro_transaccion <> -1 THEN
          IF v_max_nro_transaccion != p_cod_tra_anular THEN
            BEGIN
              select nvl(nro_transaccion, -1)
                into v_nro_transaccion
                from bw_pag_servicios b
               where b.nro_transaccion = p_cod_tra_anular
                    --where b.nro_transaccion = p_cod_transaccion
                 and b.reversado = 'N';
            EXCEPTION
              WHEN no_data_found THEN
                v_nro_transaccion := NULL;
            END;

            IF (v_nro_transaccion is null) then
              v_cod_retorno := v_cob_inexistente;
              v_des_retorno := 'Cobro inexistente';
            ELSE
              v_cod_retorno := v_ord_incorrecto;
              v_des_retorno := 'Anular antes pago posterior';
            END IF;
          END IF;
          IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
            select b.mto_transaccion, b.mto_iva_devuelto
              into v_mto_transaccion, v_mto_iva_devuelto
              from bw_pag_servicios b
             where b.nro_transaccion = p_cod_tra_anular
               and b.nro_cuenta = v_nro_cuenta
               and b.red_pago = v_red_pago
               and b.reversado = 'N'
               and b.hora = v_hora
               and b.fecha = v_fec_pago;

            if nvl(v_mto_transaccion, 0) - nvl(v_mto_iva_devuelto, 0) !=
               v_importe then
              v_cod_retorno := v_err_mto_anulacion;
              v_des_retorno := 'Importe anulacion incorrecto';
            end if;
          END IF;

        ELSE
          v_cod_retorno := v_cob_inexistente;
          v_des_retorno := 'Cobro inexistente';
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          null;
      END;
    END IF;
    IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
      pap_pre.pr_obt_dat_prestamo(v_nro_cuenta, r_ctapre); --Obtener datos del prestamo.
      v_cod_modulo := r_ctapre.cod_modulo;

      IF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_local THEN
        v_cod_moneda := '1';
      ELSIF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_fuerte THEN
        v_cod_moneda := '2';
        /*ELSE
        v_cod_retorno := pag_ser.v_mon_incorrecta;
        v_des_retorno := 'Moneda incorrecta.';*/
      END IF;
      /*IF p_cod_moneda <> v_cod_moneda THEN
         v_cod_retorno := pag_ser.v_mon_incorrecta;
         v_des_retorno := 'Moneda incorrecta.';
      END IF;*/ --se comenta por la moneda que viene en el parametro
    END IF;

    IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
      DECLARE
        v_can_cuotas NUMBER := 0;
      BEGIN
        FOR c1 IN cur_gmovi LOOP
          SELECT COUNT(*)
            INTO v_can_cuotas
            FROM pr_cobros
           WHERE nro_cuenta = c1.nro_cuenta
             AND ((fecha > c1.fecha) OR
                 (fecha = c1.fecha AND hora > c1.hora))
             AND rownum = 1;
          IF v_can_cuotas > 0 THEN
            v_cod_retorno := v_ord_incorrecto;
            v_des_retorno := 'Anular antes pago posterior';
          END IF;
        END LOOP;
      END;
    END IF;

    IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
      BEGIN
        pre_ini_aplicacion;
        pae_cnf.g_cod_modulo := v_cod_modulo;
      END;
      --
      BEGIN
        lp_ver_horario;
        IF v_horario IN ('T', 'N') THEN
          -- Tarde, Noche
          v_cob_nocturno := 'N';
          BEGIN
            select count(*)
              into v_dato
              from pr_cobros_noc
             WHERE nro_cuenta = v_nro_cuenta
               AND nro_cuota_desde = v_nro_cuota_desde
               AND fecha = v_fec_pago
               AND hora = v_hora
               AND mto_cobrado > 0;
          EXCEPTION
            WHEN no_data_found THEN
              v_cob_nocturno := 'N';
          END;

          IF nvl(v_dato, 0) > 0 then
            v_cob_nocturno := 'S';
          END IF;

          if v_cob_nocturno = 'S' then
            DELETE FROM pr_cobros_noc
             WHERE nro_cuenta = v_nro_cuenta
               AND nro_cuota_desde = v_nro_cuota_desde
               AND fecha = v_fec_pago
               AND hora = v_hora;

            IF nvl(fug_obt_pardinamico('PRE_COM_PAGSER'), 'N') = 'S' THEN
              BEGIN
                v_cod_transaccion := fue_obt_val_max_referencia('PRE_COM_TRA_PAGSER',
                                                                v_red_pago);
                DELETE FROM pr_cta_gastos
                 WHERE nro_cuenta = v_nro_cuenta
                   AND cod_transaccion = v_cod_transaccion
                   AND fec_ingreso = v_fec_pago
                   AND hor_ult_pago = v_hora;
              EXCEPTION
                WHEN no_data_found THEN
                  v_cod_retorno := pag_ser.v_err_proceso;
                  v_des_retorno := 'Error en el proceso';
              END;
            END IF;
          else
            --if v_nro_cuo_desde
            INSERT INTO pr_cobros_noc
              (nro_cuenta,
               nro_cuota_desde,
               nro_cuota_hasta,
               fecha,
               fec_proceso,
               hora,
               estado,
               mto_cobrado,
               cod_ofi_origen,
               cod_mod_padre,
               cod_mad_padre,
               cod_tra_padre,
               nro_secuencia)
            VALUES
              (v_nro_cuenta,
               v_nro_cuota,
               v_nro_cuota,
               v_fec_proxima,
               v_fec_actual,
               v_hor_actual,
               'I',
               -v_importe,
               r_ctapre.cod_oficina,
               r_ctapre.cod_modulo,
               r_ctapre.cod_modalidad,
               v_cod_tra_padre,
               nvl(v_nro_secuencia, 1));
          end if;
        ELSE
          v_concepto := 'Reversion.Pag.Prest.';

          BEGIN
            v_significado := FUE_OBT_DES_REFERENCIA('PRE_COM_TRA_PAGSER',
                                                    v_red_pago);
          EXCEPTION
            WHEN no_data_found THEN
              v_cod_retorno := pag_ser.v_err_proceso;
              v_des_retorno := 'Error en el proceso';
          END;

          v_concepto := v_concepto || v_significado;

          prg_rev_operacion(v_fec_pago,
                            v_hora,
                            v_cod_usuario,
                            r_ctapre.cod_modulo,
                            r_ctapre.cod_modalidad,
                            v_cod_tra_padre,
                            USER,
                            to_char(SYSDATE, 'HH24:MI:SS'),
                            'N',
                            v_concepto,
                            NULL);
        END IF;

      exception
        when others then
          v_cod_retorno := v_ord_incorrecto;
          --v_des_retorno := substr(sqlerrm,1,30);
          v_des_retorno := 'Cuota no puede ser revertida';
          /*v_cadena := rpad(p_cod_servicio, 5, ' ') || lpad(p_tip_transaccion, 2, '0') ||
          rpad(v_cod_retorno, 3, ' ') || rpad(v_des_retorno, 30, ' ');*/ --nrecalde
          v_cadena := v_des_retorno;
          RETURN v_cadena;
      end;
      /*actualiza a reversado el pago de servicio*/
      UPDATE bw_pag_servicios a
         SET a.reversado = 'S'
       WHERE a.nro_cuenta = v_nro_cuenta
         AND a.nro_transaccion = p_cod_tra_anular
         AND a.red_pago = v_red_pago;
    END IF;

    /*v_cadena := rpad(p_cod_servicio, 5, ' ') || lpad(p_tip_transaccion, 2, '0') ||
    rpad(v_cod_retorno, 3, ' ') || rpad(v_des_retorno, 30, ' ');*/ --nrecalde
    v_cadena := v_des_retorno;
    RETURN v_cadena;
  END fu_rev_cob_prestamo;


FUNCTION fu_rev_pago
                    (p_nro_lote in varchar2,
                     p_nro_tran in varchar2,
                     p_proceso in varchar2 default null) -- 'I' = Si es inicio de día.
return varchar2 is
 v_nro_cuenta ge_movimientos.nro_cuenta%type;
 v_fecha      ge_movimientos.fecha%type;
 v_hora       ge_movimientos.hora%type;
 v_horario   varchar2(50) ;
 v_cod_tra_padre ge_transacciones.cod_transaccion%TYPE := 485;
 v_proveedor  bw_pag_servicios.cod_proveedor%TYPE;
 v_usu_insercion bw_pag_servicios.usu_insercion%TYPE;
 v_monto    bw_pag_servicios.mto_transaccion%TYPE;
 v_cod_moneda bw_pag_servicios.cod_moneda%type;
 v_ret        number;
 v_res        number;
begin

 v_cod_respuesta :=0;
 v_msj_respuesta := 'OK';

 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

  begin
   select a.nro_cuenta, a.fecha, a.hora, a.cod_proveedor, a.usu_insercion,a.mto_transaccion,a.cod_moneda
     into v_nro_cuenta, v_fecha, v_hora, v_proveedor, v_usu_insercion,v_monto,v_cod_moneda
     from bw_pag_servicios a
    where a.nro_transaccion = p_nro_tran
      and a.nro_lote = p_nro_lote
      and a.reversado = 'N';

   v_cod_tra_padre := fu_obt_tra_padre(v_proveedor);
   lp_ver_horario;
   if nvl(p_proceso,'X') = 'I' then -- SPI 2277. CB. 04/09/2013
      v_horario := 0;
   else
      v_horario := (to_date(v_hor_actual,'HH24:MI:SS') - to_date(v_hora,'HH24:MI:SS')) * 2400 ;
   end if;
   if v_es_mov_noc = 'S' or trunc(v_horario) > 2 then
      if v_es_mov_noc = 'S' then
         -- OMM 16/02/2011 Si es movimiento nocturno
         v_cod_respuesta := 12;
         v_msj_respuesta := 'Sistema en cierre, la reversión se procesará al inicio de día';
         pr_ins_rev_cobro(p_nro_lote, p_nro_tran);
      else
         -- OMM 16/02/2011 Por que paso el tiempo maximo para reversar la operacion
         v_cod_respuesta := 11 ;
         v_msj_respuesta := 'Error al reversar. Tiempo Maximo Superado';
      end if ;
   else
    -- OMM 25/01/2011 Se busca el modulo y modalidad de la cuenta.
        pag_cta.pr_obt_cuenta(v_nro_cuenta);
        if pag_cta.fu_obt_cod_error() <> 0 then
           v_cod_respuesta := -1;
           v_msj_respuesta := 'Error al buscar la cuenta '|| v_nro_cuenta;
           raise fin_por_error;
        end if;

        prg_rev_operacion(v_fecha, v_hora, v_usu_insercion/*user*/, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, v_cod_tra_padre, user,
                          v_hor_actual,'X','Reversión.Pag.Ser. Prov:'||v_proveedor||' Lot:'||p_nro_lote||'-'||'Tran'||/*to_number(*/p_nro_tran/*)*/,null);

       /*actualiza a reversado el pago de servicio*/
       update bw_pag_servicios a
         set a.reversado = 'S'
        where a.nro_transaccion = p_nro_tran
        and a.nro_lote = p_nro_lote;
       --envio de notificaciones
       BEGIN
          v_ret:=PAW_not.fu_not_pag_servicios(v_nro_cuenta, v_monto, v_cod_moneda, 'R', SYSDATE);
       EXCEPTION
          WHEN OTHERS THEN
             NULL;
       END;
       --enviamos mail al cliente por reversion del pago a la SET o pago de servicio
       BEGIN
          v_res:= fu_env_mail_pag_servicios(p_nro_lote,v_nro_cuenta,null,v_fecha,'N',p_nro_tran);
       EXCEPTION
          WHEN OTHERS THEN
             NULL;
       END;
   end if ;
  exception
     when no_data_found then
       v_cod_respuesta := -1;
       v_msj_respuesta := 'No se encuentra la operacion';
       raise fin_por_error;
     when others then
       v_cod_respuesta := -1;
       v_msj_respuesta := sqlerrm;
       raise fin_por_error;
  end;

 if v_cod_respuesta = 0 then
  return v_cod_respuesta||'~'||v_msj_respuesta||'~'||v_fec_valor||'~'||v_hor_actual;
 else
  raise fin_por_error;
 end if;

  exception
   when fin_por_error then
         return v_cod_respuesta||'~'||v_msj_respuesta||'~'||v_fec_valor||'~'||v_hor_actual;
   when others then
         return 'Ha ocurrido un error no manejado, intente nuevamente más tarde.';
  end;

FUNCTION fu_val_ins_sesion(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                           p_cod_per_empresa IN ba_personas.cod_persona%TYPE)
  RETURN VARCHAR2 IS
  v_fec_insercion date;
  v_retorno       varchar2(1) := 'S';
  v_min_sesion    number;
BEGIN
  -- obtenemos el tiempo mínimo
  begin
    v_min_sesion := nvl(trim(fug_obt_pardinamico('BCA_MIN_SERVICIO')), 0);
  exception
    when others then
      v_min_sesion := 0;
  end;
  -- se busca la ultima creacion de la sesión
  begin
    select a.fec_insercion
      into v_fec_insercion
      from bw_sesiones a
     where a.cod_persona = p_cod_persona
       and nvl(a.cod_per_vinculada, 'x') = nvl(p_cod_per_empresa, 'x')
       and rownum=1;
    -- se verifica que exista un tiempo mínimo de PAW_MIN_SESION minutos para crear otra sesión
    if ((sysdate)-v_fec_insercion)*1440 <= v_min_sesion then
      v_retorno := 'N';
    end if;
  exception
    when others then
      null; -- no se ingresó aún la sesión, no se hace nada
  end;
  return v_retorno;
END;

FUNCTION fu_ins_sesion(p_sesion            IN VARCHAR2,
                       p_nro_ip            IN VARCHAR2,
                       p_cod_persona       IN ba_personas.cod_persona%TYPE,
                       p_cod_per_empresa   IN ba_personas.cod_persona%TYPE,
                       p_cuenta            IN ge_cuentas.nro_cuenta%TYPE)
  RETURN VARCHAR2 IS
  PRAGMA AUTONOMOUS_TRANSACTION;
v_existe  varchar2(1);
v_retorno varchar2(1) := 'S';
BEGIN
  --buscamos si hay una sesión existente
  begin
    select decode(count(*),0,'N','S')
      into v_existe
      from bw_sesiones a
     where a.cod_persona = p_cod_persona
       and nvl(a.cod_per_vinculada, 'x') = nvl(p_cod_per_empresa, 'x');
  exception
    when no_data_found then
      v_existe := 'N';
  end;
  -- si existe eliminamos la existente
  if v_existe = 'S' then
     delete bw_sesiones a
      where a.cod_persona = p_cod_persona
        and nvl(a.cod_per_vinculada, 'x') = nvl(p_cod_per_empresa, 'x');
     commit;
  end if;

  begin
    -- se inserta la sesión
    insert into bw_sesiones
      (nro_sesion, nro_ip, cod_persona, hor_inicio,
       fec_inicio, cod_per_vinculada, nro_cuenta)
    values
      (p_sesion, trim(p_nro_ip), p_cod_persona, v_hor_actual,
       v_fec_actual, p_cod_per_empresa, p_cuenta);
    commit;
   exception
     when others then
       v_retorno := 'N'; -- no se pudo crear la sesión
   end;
   return v_retorno;
END;

/* Procedimiento que inserta las reversiones por cobro de servicios que no se procesaron
   por estar en cierre. SPI 2277. CB. 04/09/2013*/
PROCEDURE pr_ins_rev_cobro( p_nro_lote        IN varchar2,
                            p_nro_transaccion IN varchar2) IS
   PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN
   insert into ge_cob_ser_reversados  (nro_lote, nro_transaccion, procesado)
   values (p_nro_lote, p_nro_transaccion, 'N');
   COMMIT;
EXCEPTION
   when others then
     null;
END;

/* Procedimiento de Inicio de día que inseta las reversiones de cobro que no se pudieron
   realizar mientras el sistema estaba en cierre. SPI 2277. CB. 04/09/2013*/
PROCEDURE pr_pro_rev_cobro IS
   cursor rev_cobros is
      select a.nro_lote, a.nro_transaccion
        from ge_cob_ser_reversados a
       where a.procesado = 'N';
   v_respuesta varchar2(500);
   -- DYDMR-5770 01/2017 NAF
   v_acu_resp varchar2(4000) := NULL;
   v_err_con number := 0;
   v_err_upd varchar2(1);
   v_msj_upd varchar2(100);
BEGIN
   for cob in rev_cobros loop
      --DYDMR-2137 ITGF - Error de PK PAG_SER.PR_PRO_REV_COBRO - SC 17827
      --v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);
      v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
      v_respuesta := fu_rev_pago(cob.nro_lote, cob.nro_transaccion, 'I');
      if v_cod_respuesta <> 0 then
         -- DYDMR-5770 01/2017 NAF
         v_err_con := v_err_con + 1;
         if v_acu_resp is null then
           v_acu_resp := ' movimientos que no pudieron reversarse: ';
         end if;
         if LENGTH(v_acu_resp)+LENGTH(v_respuesta) < 3900 then
            v_acu_resp := v_acu_resp || v_respuesta;
         end if;
      else
          v_err_upd := 'N';
          v_msj_upd := '';
          begin
             update ge_cob_ser_reversados
                set procesado = 'S'
              where nro_lote = cob.nro_lote
                and nro_transaccion = cob.nro_transaccion;
          exception
             when others then
                -- DYDMR-5770 01/2017 NAF
                v_err_con := v_err_con + 1;
                v_err_upd := 'S';
                v_msj_upd := ' Error al actualizar ge_cob_ser_reversados lote '|| cob.nro_lote
                           || 'trans.: '||cob.nro_transaccion;
                --raise_application_error (-20070,'Error al actualizar ge_cob_ser_reversados. '||sqlerrm);
                if LENGTH(v_acu_resp)+LENGTH(v_msj_upd) < 4000 then
                   v_acu_resp := v_acu_resp || v_msj_upd;
                end if;
          end;
          -- DYDMR-5770 01/2017 NAF realiza commit si no hay error
          if v_err_upd = 'N' then
             commit;
          else
             rollback;
          end if;
       end if;
   end loop;
   if v_acu_resp is not null then
      raise fin_por_error;
   end if;
EXCEPTION
   when fin_por_error then
      raise_application_error (-20071, 'Hay ' || v_err_con || v_acu_resp);
   when others then
      raise_application_error (-20072,'No se pudo insertar la reversión. '||sqlerrm);
END;

PROCEDURE pr_obt_cup_vencidos( p_nro_documento   IN ba_personas.nro_documento%type,
                                 p_serie           IN ah_cta_certificados.serie%type,
                                 p_nro_certificado IN ah_cta_certificados.nro_certificado%type,
                                 p_cod_moneda      IN ah_cta_certificados.cod_moneda%type,
                                 p_reg_firma       IN OUT ah_cta_certificados.reg_firma%type,
                                 p_imagen          IN OUT long,
                                 p_nro_cupon       IN OUT ah_cupones.nro_cupon%type,
                                 p_nro_cuenta_tit  IN OUT varchar2,
                                 p_beneficiario    IN OUT varchar2,
                                 p_moneda          IN OUT varchar2,
                                 p_monto           IN OUT ah_cupones.mto_interes%type,
                                 p_fecha_venc      IN OUT ah_cupones.fec_vencimiento%type,
                                 p_cod_respuesta   out varchar2,
                                 p_msj_respuesta   out varchar2
                                 )
                                 is
  v_relacion                     varchar2(1):=null;
  v_cod_respuesta varchar2(03)           := '000'; -- sin errores
  v_msj_respuesta varchar2(4000)         := 'Operacion Confirmada'; -- sin errores
  -- JFF Procedimiento para obtener cupones
 BEGIN
   begin
     SELECT cc.relacion
        into v_relacion
     from ah_cta_certificados t, ge_cta_clientes cc, ba_personas b
     where t.nro_cuenta=cc.nro_cuenta
     and cc.cod_persona=b.cod_persona
     and t.serie=p_serie
     and t.nro_certificado= p_nro_certificado
     and b.nro_documento = p_nro_documento;
   exception
     when no_data_found then
           v_relacion      := null;
           v_cod_respuesta := '001';
           v_msj_respuesta := 'ERROR: no encuentra la relacion';
           p_cod_respuesta := v_cod_respuesta;
           p_msj_respuesta := v_msj_respuesta;
   end;
   if v_cod_respuesta = '000' then
             Begin
                if v_relacion = 'P' then
                      select h.nro_cupon,
                             c.nro_cuenta || ' - ' || p.nom_completo nombre_cliente,
                             r.beneficiario otro_beneficiario,
                             '(' || r.cod_moneda || ') ' || m.descripcion moneda,
                             h.mto_interes monto,
                             h.fec_vencimiento
                        into p_nro_cupon,
                             p_nro_cuenta_tit,
                             p_beneficiario,
                             p_moneda,
                             p_monto,
                             p_fecha_venc
                        from ge_cta_clientes     c,
                             ba_personas         p,
                             ah_cta_certificados r,
                             ah_cupones          h,
                             ba_monedas          m
                       where c.cod_persona = p.cod_persona
                         and c.nro_cuenta = r.nro_cuenta
                         and r.nro_cuenta = h.nro_cuenta
                         and r.cod_moneda = m.cod_moneda
                         and h.estado = 'V'
                         and r.estado not in ('T', 'A')
                         and c.relacion = 'P'
                         and p.nro_documento = p_nro_documento
                         and r.serie = p_serie
                         and r.nro_certificado = p_nro_certificado
                         and r.cod_moneda = p_cod_moneda
                         and h.fec_vencimiento = (select min(n.fec_vencimiento) from ah_cupones n
                                                   where n.nro_cuenta = r.nro_cuenta
                                                     and n.estado = h.estado )


                         ;

             ELSE
                select r.reg_firma,
                         f.ima_firma firma,
                         h.nro_cupon,
                         c.nro_cuenta || ' - ' || p.nom_completo nombre_cliente,
                         r.beneficiario otro_beneficiario,
                         '(' || r.cod_moneda || ') ' || m.descripcion moneda,
                         h.mto_interes monto,
                         h.fec_vencimiento
                    into p_reg_firma,
                         p_imagen,
                         p_nro_cupon,
                         p_nro_cuenta_tit,
                         p_beneficiario,
                         p_moneda,
                         p_monto,
                         p_fecha_venc
                    from ge_cta_clientes     c,
                         ba_personas         p,
                         ah_cta_certificados r,
                         ah_cupones          h,
                         ba_monedas          m,
                         ba_per_firmas       f
                   where c.cod_persona = p.cod_persona
                     and c.nro_cuenta = r.nro_cuenta
                     and r.nro_cuenta = h.nro_cuenta
                     and r.cod_moneda = m.cod_moneda
                     and c.cod_persona=f.cod_persona
                     and h.estado = 'V'
                     and r.estado not in ('T', 'A')
                     and c.relacion <> 'P'
                     and p.nro_documento = p_nro_documento
                     and r.serie = p_serie
                     and r.nro_certificado = p_nro_certificado
                     and r.cod_moneda = p_cod_moneda
                     and h.fec_vencimiento = (select min(n.fec_vencimiento) from ah_cupones n
                                               where n.nro_cuenta = r.nro_cuenta
                                                 and n.estado = h.estado )   ;
              END IF;
         exception
             when others then
               v_cod_respuesta := '002';
               v_msj_respuesta := 'ERROR: '||sqlerrm;
               p_cod_respuesta         := v_cod_respuesta;
               p_msj_respuesta         := v_msj_respuesta;

          END;
          p_cod_respuesta := v_cod_respuesta;
          p_msj_respuesta := v_msj_respuesta;
    END IF;
 END ;

 PROCEDURE pr_obt_cda_vencidos( p_nro_documento   IN ba_personas.nro_documento%type,
                                 p_serie           IN ah_cta_certificados.serie%type,
                                 p_nro_certificado IN ah_cta_certificados.nro_certificado%type,
                                 p_cod_moneda      IN ah_cta_certificados.cod_moneda%type,
                                 p_reg_firma       OUT ah_cta_certificados.reg_firma%type,
                                 p_imagen          OUT long,
                                 p_nro_cuenta_tit  OUT varchar2,
                                 p_beneficiario    OUT varchar2,
                                 p_moneda          IN OUT varchar2,
                                 p_plazo           OUT number,
                                 p_monto           OUT ah_cta_certificados.capital%type,
                                 p_sal_disponible  OUT ah_cta_certificados.sal_total%type,
                                 p_fec_apertura    OUT ah_cta_certificados.fec_apertura%type,
                                 p_fecha_venc      OUT ah_cupones.fec_vencimiento%type,
                                 p_cod_respuesta   out varchar2,
                                 p_msj_respuesta   out varchar2
                                 )
                                 is
  v_relacion                     varchar2(1):=null;
  v_rel_princial                 varchar2(1):=null;
  v_cod_tip_documento            ba_personas.cod_tip_documento%type;
  v_cod_respuesta varchar2(03)           := '000'; -- sin errores
  v_msj_respuesta varchar2(4000)         := 'Operacion Confirmada'; -- sin errores
  -- JFF Procedimiento para consultar CDA
 BEGIN
   v_relacion          := null;
   v_rel_princial      := null;
   begin
     SELECT cc.relacion
        into v_relacion
     from ah_cta_certificados t, ge_cta_clientes cc, ba_personas b
     where t.nro_cuenta=cc.nro_cuenta
       and cc.cod_persona=b.cod_persona
       and t.serie=p_serie
       and t.nro_certificado= p_nro_certificado
       and b.nro_documento = p_nro_documento
       and t.cod_moneda    = p_cod_moneda;
       if v_relacion<>'P' then
           SELECT cc.relacion
             into v_rel_princial
           from ah_cta_certificados t, ge_cta_clientes cc, ba_personas b
           where t.nro_cuenta=cc.nro_cuenta
             and cc.cod_persona=b.cod_persona
             and t.serie=p_serie
             and t.nro_certificado= p_nro_certificado
             and t.cod_moneda    = p_cod_moneda
             and cc.relacion = 'P';
       end if;
   exception
     when no_data_found then
           v_cod_respuesta := '001';
           if v_rel_princial is null and v_relacion is not null then
                      v_msj_respuesta := 'ERROR: No se encuentra la relacion Principal para el CDA';
           else
                      v_msj_respuesta := 'ERROR: No se encuentra la relacion para el CDA';
           end if;
           p_cod_respuesta := v_cod_respuesta;
           p_msj_respuesta := v_msj_respuesta;
   end;
   if v_cod_respuesta = '000' then
             Begin
             if v_relacion = 'P' then
                 select c.nro_cuenta||' - '||p.nom_completo nombre_cliente,r.beneficiario otro_beneficiario,
                             trunc(r.fec_vencimiento - r.fec_apertura) plazo, r.capital, r.fec_apertura, r.fec_vencimiento,
                             r.cod_moneda, r.sal_total
                       into
                             p_nro_cuenta_tit,
                             p_beneficiario,
                             p_plazo,
                             p_monto,
                             p_fec_apertura,
                             p_fecha_venc,
                             p_moneda,
                             p_sal_disponible


                        from ge_cta_clientes c, ba_personas p, ah_cta_certificados r, ba_monedas m
                        where c.cod_persona=p.cod_persona
                          and c.nro_cuenta=r.nro_cuenta
                          and r.cod_moneda= m.cod_moneda
                          and r.est_certificado = 'V'
                          and r.estado not in ('T','A')
                          and c.relacion='P'
                          and p.nro_documento=p_nro_documento
                          and r.serie=p_serie
                          and r.nro_certificado =p_nro_certificado
                          and r.cod_moneda    = p_cod_moneda
                          ;

             ELSE
                -- Firmantes <> Principal (firmantes)
                  select c.nro_cuenta||' - '||p.nom_completo nombre_cliente,r.beneficiario otro_beneficiario,
                   trunc(r.fec_vencimiento - r.fec_apertura) plazo, r.capital, r.fec_apertura, r.fec_vencimiento, r.reg_firma,
                   nvl( (
                  select f.ima_firma from ba_per_firmas f
                  where f.cod_persona =  (SELECT cc.cod_persona
                                            from ah_cta_certificados t, ge_cta_clientes cc, ba_personas b
                                           where t.nro_cuenta=cc.nro_cuenta
                                             and cc.cod_persona=b.cod_persona
                                             and t.serie=p_serie
                                             and t.nro_certificado= p_nro_certificado
                                             and t.cod_moneda    = p_cod_moneda
                                             and cc.relacion='P')
                                             ),fi.ima_firma) ima_firma, r.cod_moneda, r.sal_total
                    into p_nro_cuenta_tit,
                         p_beneficiario,
                         p_plazo,
                         p_monto, -- capital
                         p_fec_apertura,
                         p_fecha_venc,
                         p_reg_firma,
                         p_imagen,
                         p_moneda,
                         p_sal_disponible

                  from ge_cta_clientes c, ba_personas p, ah_cta_certificados r, ba_monedas m, ba_per_firmas fi
                  where c.cod_persona=p.cod_persona
                    and c.nro_cuenta=r.nro_cuenta
                    and r.cod_moneda= m.cod_moneda
                    and r.est_certificado = 'V'
                    and r.estado not in ('T','A')
                    and c.relacion<>'P'
                    and p.nro_documento=p_nro_documento
                    and r.serie=p_serie
                    and r.nro_certificado =p_nro_certificado
                    and r.cod_moneda    = p_cod_moneda
                    and c.cod_persona = fi.cod_persona ;

              END IF;
         exception
             when others then
               v_cod_respuesta := '002';
               v_msj_respuesta := 'ERROR: '||sqlerrm;
               p_cod_respuesta         := v_cod_respuesta;
               p_msj_respuesta         := v_msj_respuesta;

          END;
          p_cod_respuesta := v_cod_respuesta;
          p_msj_respuesta := v_msj_respuesta;
    END IF;
 END ;

PROCEDURE pr_rev_cda_vencido
       (
        p_nro_transaccion IN ge_movimientos.nro_documento3%type,
        p_usuario    IN ba_usuarios.cod_usuario%type,
        p_fecha      IN date,
        p_cod_respuesta   out varchar2,
        p_msj_respuesta   out varchar2
       )
        IS

    v_nro_cuenta            ge_movimientos.nro_cuenta%type;
    v_cod_modulo            ah_cta_certificados.cod_modulo%type;
    v_cod_modalidad         ah_cta_certificados.cod_modalidad%type;
    v_nro_documento         ge_movimientos.nro_documento%type;
    v_denominacion          ge_cuentas.denominacion%type;
    v_cod_moneda            ge_movimientos.cod_moneda%type;
    v_concepto              ge_movimientos.concepto%type;
    v_monto                 ge_movimientos.monto%type;
    v_nro_documento2        ge_movimientos.nro_documento2%type := null;
    v_cod_mad_padre         ge_movimientos.cod_mad_padre%type  := null;
    v_cod_tra_padre         ge_movimientos.cod_tra_padre%type  := null;
    v_nro_lote              ge_movimientos.nro_documento2%type;
    v_cod_trans_sue         ge_movimientos.cod_transaccion%type;
    v_fec_valor             ge_movimientos.fec_valor%type;
    v_hora_aux              ge_movimientos.hora%type;
    v_cod_servicio          bw_pag_servicios.cod_servicio%type;

    v_cod_respuesta varchar2(03)           := '000'; -- sin errores
    v_msj_respuesta varchar2(4000)         := 'Operacion Confirmada'; -- sin errores




BEGIN
    v_cod_modulo := 3;
    v_hora_aux   := null;
  begin
  -- traemos los datos del movimiento
   select b.hora, b.nro_cuenta, a.denominacion, b.cod_moneda,
             nvl(b.monto,0), b.nro_documento2, b.cod_mad_padre,
             b.cod_tra_padre, b.nro_documento2, b.cod_transaccion, b.fec_valor, b.nro_documento
     into v_hora_aux, v_nro_cuenta,   v_denominacion, v_cod_moneda,
          v_monto, v_nro_documento2, v_cod_mad_padre,
          v_cod_tra_padre,  v_nro_lote,v_cod_trans_sue, v_fec_valor, v_nro_documento
     from ge_cuentas a, ge_movimientos b
    where a.nro_cuenta(+) = b.nro_cuenta
      and b.cod_modulo = v_cod_modulo  -- JFF 23/08/2022
      and b.estado in('N','J','X','P') -- Normal
      and b.reversado ='N'             -- no reversados
      and b.cod_usuario = p_usuario
      and b.fecha = p_fecha
      and b.nro_documento3 = p_nro_transaccion
      and (b.nro_secuencia = ( Select min(c.nro_secuencia)
                                from  ge_movimientos c
                               where c.cod_tra_padre = b.cod_tra_padre
                                 and c.estado in('N','J','X','P') -- Normal
                                 and c.reversado ='N'             -- no reversados
                                 and c.cod_usuario = p_usuario
                                 and c.nro_documento3 = p_nro_transaccion
                                 and ((c.cod_tra_padre = b.cod_tra_padre AND c.cod_mod_padre <> 28) OR
                                 (c.cod_tra_padre = b.cod_tra_padre AND c.cod_modulo = v_cod_modulo AND
                                 c.cod_mod_padre = 28) OR (c.cod_tra_padre = b.cod_tra_padre AND c.cod_modulo IS NULL
                                 AND c.cod_mod_padre = 28)OR (c.cod_tra_padre = b.cod_tra_padre
                                 AND c.cod_mod_padre = 28))));
   exception
    when others then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR Consulta movimiento '||sqlerrm;

   end;
 if v_cod_respuesta = '000' then
       begin

           if v_fec_valor<>p_fecha then
               update bw_pag_servicios t
              set t.reversado='S'
            where t.nro_cuenta= v_nro_cuenta
              and t.nro_transaccion = p_nro_transaccion
              and t.usu_insercion = p_usuario
              and t.fecha= v_fec_valor;
           else
              update bw_pag_servicios t
              set t.reversado='S'
            where t.nro_cuenta= v_nro_cuenta
              and t.nro_transaccion = p_nro_transaccion
              and t.usu_insercion = p_usuario
              and t.fecha= p_fecha;
           end if;

           -- Actualiza la cuenta
           begin
              select b.cod_servicio
              into v_cod_servicio
              from bw_pag_servicios b
             where nro_cuenta = v_nro_cuenta
               and nro_transaccion = p_nro_transaccion
               and b.usu_insercion = p_usuario
              and b.fecha= p_fecha;
           exception
              when others then
               v_cod_respuesta := '004';
               v_msj_respuesta := 'ERROR al reversar '||sqlerrm;
               p_cod_respuesta := v_cod_respuesta;
               p_msj_respuesta := v_msj_respuesta;
           end;
          if v_cod_servicio = 659 then
            v_concepto      :=  'Rev. Pago de Cupon';
           elsif v_cod_servicio = 660 then
            v_concepto      :=  'Rev. Pago de CDA';
           end if;


           prg_rev_operacion( p_fecha,
                              v_hora_aux,
                              p_usuario,
                              v_cod_modulo,
                              v_cod_modalidad,
                              v_cod_tra_padre,
                              p_usuario,
                             to_char(sysdate,'hh24:mi:ss'),
                             'N',--Es nocturno.
                             v_concepto,
                             v_nro_documento);

       exception
        when others then
          v_cod_respuesta := '002'; -- error
          v_msj_respuesta := 'ERROR al reversar '||sqlerrm;
          p_cod_respuesta   := v_cod_respuesta;
          p_msj_respuesta   := v_msj_respuesta;

       end;
end if;
    p_cod_respuesta   := v_cod_respuesta;
    p_msj_respuesta   := v_msj_respuesta;

exception
  when others then
      v_cod_respuesta := '003'; -- error
      v_msj_respuesta := 'ERROR al reversar '||sqlerrm;
      p_cod_respuesta   := v_cod_respuesta;
      p_msj_respuesta   := v_msj_respuesta;

END;

 PROCEDURE pr_pag_cda_cupon_vencido ( p_nro_documento     in ba_personas.cod_persona%type,
                                     p_nro_certificado   in ah_cta_certificados.nro_certificado%type,
                                     p_cod_moneda        in ah_cta_certificados.cod_moneda%type,
                                     p_serie             in ah_cta_certificados.serie%type,
                                     p_cod_ente          in varchar2,
                                     p_cod_servicio      in number,
                                     p_agencia           in bw_pag_servicios.pto_cobranza%type default null,
                                     p_nro_transaccion   in bw_pag_servicios.nro_transaccion%type,
                                     p_nro_cupon         in varchar2, -- Nro del cupon
                                     P_importe           in varchar2 default null,
                                     p_tipo              in varchar2,
                                     p_fecha             in date,
                                     p_nro_cuenta        in varchar2 default null,
                                     p_cod_respuesta   out varchar2,
                                     p_msj_respuesta   out varchar2
                                     )                 IS
       v_nro_cuenta             varchar2(15);
       v_beneficiario           ah_cta_certificados.beneficiario%type;
       v_mto_interes            ah_cupones.mto_interes%type;
       v_fec_vencimiento        ah_cupones.fec_vencimiento%type;
       v_est_cupon              ah_cupones.estado%type;
       v_estado                 ah_cta_certificados.estado%type;
       v_bloqueado              ah_cupones.bloqueado%type;
       v_denominacion           ah_cta_certificados.denominacion%type;
       v_est_cuenta             varchar2(1);       -- estado de la cuenta
       v_nro_secuencia          ge_movimientos.nro_secuencia%type;
       v_cod_rubro              cb_sal_inventarios.cod_rubro%type;
       v_cod_modulo             number(3);
       v_cod_modalidad          number(3);
       v_cod_transaccion        number(4);   -- transaccion
       v_tip_cuenta             number(3);         -- tipo de cuenta(modalidad)
       v_capital                number(18,2);      -- capital de la cuenta
       v_sal_disponible         number(18,2);      -- saldo disponible
       v_est_certificado        varchar2(1);       -- estado del certificado
       v_fecha                  date;
       v_importe                number := to_number(p_importe);
       v_cod_moneda             ah_cta_certificados.cod_moneda%type;
       v_redondeo               number;
       v_cod_oficina            ba_usuarios.cod_oficina%type;
       v_fec_actual             date := pag_cal.fu_obt_fec_actual(1); -- fecha de hoy
       v_hor_actual             varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
       v_lote                   bw_pag_servicios.nro_lote%type := 0;
       v_lugar                  varchar2(400);
       v_cuenta_cn              ge_movimientos.nro_cuenta%type;
       v_cod_ente               ge_entes.cod_ente%type;
       v_des_servicio           ba_cod_referencias.significado%type;
       v_concepto_aux           ge_movimientos.concepto%type;
       r_gmovi                  ge_movimientos%rowtype;
       v_con_transaccion        number(10);
       v_red_pago               varchar2(1);
       -- Datos de salida
  v_cod_respuesta varchar2(03)           := '000'; -- sin errores
  v_msj_respuesta varchar2(4000)         := 'Operacion Confirmada'; -- sin errores


  procedure lp_ins_bw_pag_ser(p_nro_documento number) is
    v_tipo      number(1);

    begin
      if p_tipo='E' then
         v_tipo:=1;
      else
         v_tipo:=3;
      end if;
       begin
          select nvl(max(to_number(nro_lote)),0)+1
              into v_lote
              from bw_pag_servicios
             where nro_cuenta = v_nro_cuenta
               and nro_transaccion = p_nro_transaccion;
         exception
            when no_data_found then
              v_lote := 0;
         end;
      INSERT INTO bw_pag_servicios
                        (nro_cuenta,
                         cod_servicio,
                         fecha,
                         hora,
                         nro_transaccion,
                         nro_lote,
                         ip_usuario,
                         terminal,
                         cod_moneda,
                         mto_transaccion,
                         mto_comision,
                         mto_mora,
                         mto_interes,
                         reversado,
                         mto_debito,
                         cod_mon_servicio,
                         tip_pago,
                         cod_banco,
                         nro_cheque,
                         red_pago,
                         pto_cobranza,
                         nro_recibo,
                         mto_capital,
                         mto_impuesto,
                         mto_int_adelantado,
                         mto_punitorio,
                         mto_iva_devuelto,
                         cod_rubro,
                         des_servicio,
                         par_enviados)
              VALUES
                        (v_nro_cuenta,
                         v_cod_servicio,
                         v_fec_actual,
                         v_hor_actual,
                         p_nro_transaccion,
                         v_lote,
                         user,
                         null,
                         p_cod_moneda,
                         v_importe,
                         0,
                         0,
                         0,
                         'N',
                         v_importe,
                         NULL,
                         v_tipo,
                         0,
                         null,
                         v_red_pago,
                         p_agencia,
                         null,
                         0,
                         0,
                         0,
                         0,
                         0,
                         v_cod_rubro,
                         v_des_servicio,
                         nvl(p_nro_documento, p_nro_cupon)
                         );
    exception
        when others then
             v_cod_respuesta := '007'; -- error
             v_msj_respuesta := 'ERROR: bw_pag_servicios. '||sqlerrm;
    end;
    procedure lp_ins_deb_operacion(p_nro_documento number, p_tipo_dc varchar) is
              v_tra_hijo ge_movimientos.cod_transaccion%type;
    Begin
            v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
             if p_cod_servicio = 659 then
                 if p_tipo_dc = 'D' then
                  v_tra_hijo := 547;
                elsif p_tipo_dc ='C' then
                   v_nro_cuenta := p_nro_cuenta;
                    v_tra_hijo := 602;
                end if;
             else
                if p_tipo_dc = 'D' then
                  v_tra_hijo := 503;
                elsif p_tipo_dc ='C' then
                   v_nro_cuenta := p_nro_cuenta;
                    v_tra_hijo := 602;
                end if;
             end if;



           pag_cta.PR_SET_NRO_DOCUMENTO3(p_nro_transaccion);
           pag_cta.pr_act_operacion(v_nro_cuenta,
                                       v_hor_actual,
                                       p_tipo_dc, -- debito a la cuenta del cliente
                                       p_cod_moneda,
                                       v_importe,
                                       v_cod_transaccion,
                                       v_tra_hijo,
                                       p_nro_documento,
                                       null, -- cotizacion
                                       v_cod_oficina,
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       null, -- tasa
                                       null, -- valor de tasa
                                       v_concepto_aux, --concepto
                                       'N', -- emitir aviso
                                       v_nro_secuencia, -- nro de secuencia
                                       v_fec_actual);
               if pag_cta.g_cod_error <> 0 then
                   -- actualizacion con problemas
                   v_cod_respuesta := '008';
                   v_msj_respuesta := pag_cta.g_msj_error;
               end if;
     exception
        when others then
             v_cod_respuesta := '009'; -- error
             v_msj_respuesta := 'ERROR: Inserta Operación '||sqlerrm;
    end;

BEGIN
  v_lugar:='Inicio';
  v_nro_secuencia   := 0;
  v_redondeo        := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',3,33,p_cod_moneda);
  v_cod_oficina     := it.FUG_OBT_OFI_USUARIO(user);


  -- Referencia pago interes CDA
  Begin
    select r.val_maximo, r.val_minimo
      into v_cod_ente, v_red_pago
      from ba_cod_referencias r
     where r.dominio          = 'PRE_COM_TRA_PAGSER'
       and r.val_maximo       = p_cod_ente
       and r.abreviatura      = 'CN';
   exception
     when others then
          v_cod_respuesta := '001'; -- error
          v_msj_respuesta := 'ERROR: Validacion codigo de Ente.'||sqlerrm;
   End;

   Begin
     select r.significado
       into v_des_servicio
       from ba_cod_referencias r
      where r.dominio         = 'DES_OPE_COB_SER'
        and r.val_maximo      = p_cod_ente
        and r.val_minimo      = p_cod_servicio;
   exception
     when others then
          v_cod_respuesta := '002'; -- error
          v_msj_respuesta := 'ERROR: Descripcion del servicio'||sqlerrm;
   End;
  if p_fecha is null then
     v_fecha := v_fec_actual;
  else
     v_fecha := p_fecha;
  end if;
  -- v_fec_actual := v_fecha; -- se comenta porque pisa el valor de fec_actual y no coincide la fecha del movimiento
  if v_cod_respuesta = '000' then
        if p_serie is null then  -- valido la serie
           v_cod_respuesta := '003'; -- error
           v_msj_respuesta := 'ERROR: Ingrese la Serie del Certificado.';
        elsif p_nro_certificado is null then  -- valido el nro de certificado
           v_cod_respuesta := '004'; -- error
           v_msj_respuesta := 'ERROR: Ingrese el Numero del Certificado.';
        elsif v_importe is null or v_importe <= 0 then
           v_cod_respuesta := '005'; -- error
           v_msj_respuesta := 'ERROR: Ingrese el importe del Certificado.';
        elsif nvl(p_importe,0) <> nvl(round(p_importe,v_redondeo),0) then
             v_cod_respuesta := '006';
             v_msj_respuesta := 'Decimales incorrectos para la moneda.';
        elsif p_nro_transaccion is null then -- valido la transaccion
             v_cod_respuesta := '007'; -- error
             v_msj_respuesta := 'ERROR: Ingrese el Número de Transacción.';
        end if;
        if v_cod_respuesta= '000' then
         -- obtenemos la cuenta rubro
         if p_cod_moneda = it.pag_gen.fu_obt_mon_local then
           v_cuenta_cn := it.fug_obt_parentes(v_cod_ente, 'CTA_SER_CDA_GS');
         elsif p_cod_moneda = it.pag_gen.fu_obt_mon_fuerte then
           v_cuenta_cn := it.fug_obt_parentes(v_cod_ente, 'CTA_SER_CDA_USD');
         end if;
     end if;

         -- Verificar si es pago interes(cupon) o capital CDA
         if p_cod_servicio = 659 AND v_cod_respuesta='000' then -- Cupon
               v_cod_servicio := p_cod_servicio;
               if p_nro_cupon is null then
                  v_cod_respuesta := '010'; -- error
                  v_msj_respuesta := 'ERROR: Ingrese el Nro. de Cupon.';
               else
                    v_concepto_aux := 'PAGO DE CUPON';
                    BEGIN
                     Select cda.nro_cuenta,
                            cda.beneficiario,
                            cda.estado,
                            cup.mto_interes,
                            cup.fec_vencimiento,
                            cda.estado,
                            cup.estado,
                            cup.bloqueado,
                            cda.denominacion

                       into v_nro_cuenta,
                            v_beneficiario,
                            v_est_cuenta,
                            v_mto_interes,
                            v_fec_vencimiento,
                            v_estado,
                            v_est_cupon,
                            v_bloqueado,
                            v_denominacion
                       from ah_cta_certificados cda,
                            ah_cupones cup
                       where cup.estado = 'V' and
                             cup.nro_cupon       = p_nro_cupon and
                             cda.nro_certificado = p_nro_certificado and
                             cda.serie           = p_serie           and
                             cda.nro_cuenta      = cup.nro_cuenta   and
                             cda.cod_moneda      = p_cod_moneda     ;
                     If v_bloqueado = 'S' then
                        v_cod_respuesta := '011'; -- error
                        v_msj_respuesta := 'ERROR: Ingrese el importe del Certificado.';

                     End if;


                  exception
                    when no_data_found then
                         v_cod_respuesta := '012';
                         v_msj_respuesta := 'ERROR: Nro de Cupon no existe o esta vencido para este Documento!';

                    when others then
                         v_cod_respuesta := '013';
                         v_msj_respuesta := 'ERROR: '||sqlerrm;
                  END;

                  if v_est_cuenta in ('A','T','C','D') then
                    v_cod_respuesta := '014';
                    v_msj_respuesta := 'ERROR: Cuenta no esta activa. Verifique!';
                  else
                      IF v_cod_respuesta ='000' THEN
                         if v_est_cupon <> 'V' then
                            v_cod_respuesta := '009';
                            v_msj_respuesta := 'ERROR: Nro de Cupon no esta vencido!';
                         elsif p_importe <> v_mto_interes then -- Modificado para que permita pagos parciales en CDA
                            v_cod_respuesta := '009';
                            v_msj_respuesta := 'ERROR: El Importe del Documento no corresponde.';
                         end if;
                         if v_importe <> v_mto_interes then -- Modificado para que permita pagos parciales en CDA
                            v_cod_respuesta := '015';
                            v_msj_respuesta := 'ERROR: El Importe del Documento no corresponde.';
                         elsif  nvl(p_importe,0) <> nvl(v_mto_interes,0) then   --- Validar detalle de la forma de pago
                            v_cod_respuesta := '016';
                            v_msj_respuesta := 'El detalle de la forma de cobro debe coincidir con el interés vencido';
                         end if;
                     END IF;
                     v_cod_modulo       := 3;
                     v_cod_modalidad    := 33;
                     v_cod_transaccion    := 311;  -- transaccion padre
                      -- Consulta nro de transaccion en los CDA  cupones
                            v_con_transaccion :=0;
                            begin
                              select nvl(count(m.nro_documento3),0)
                                into v_con_transaccion
                                from ge_movimientos m
                               where m.nro_documento =P_NRO_CUPON
                                 and m.nro_documento3=p_nro_transaccion;
                                 if nvl(v_con_transaccion,0)>0 then
                                   v_cod_respuesta := '025';
                                   v_msj_respuesta  :=  'Ya se encuentra ingresado el nro de transaccion ' || p_nro_transaccion;
                                 end if;
                            exception
                              when others then
                                  v_cod_respuesta := '026';
                                  v_msj_respuesta  :=  'Error: al consultar nro de transaccion ' || p_nro_transaccion;
                            end ;
                    IF p_tipo = 'E' and v_cod_respuesta ='000' then
                         lp_ins_bw_pag_ser(p_nro_cupon);
                         lp_ins_deb_operacion(p_nro_cupon, 'D');
                         if v_cod_respuesta ='000' then
                              pag_cta.PR_SET_NRO_DOCUMENTO3(p_nro_transaccion);
                               v_nro_secuencia := v_nro_secuencia + 1;
                              pag_cta.pr_act_operacion(v_cuenta_cn,
                                                       v_hor_actual,
                                                       'C', -- debito o credito
                                                       p_cod_moneda,
                                                       v_importe,
                                                       v_cod_transaccion,
                                                       602,
                                                       p_nro_cupon,
                                                       null, -- cotizacion
                                                       v_cod_oficina,
                                                       v_cod_modulo,
                                                       v_cod_modalidad,
                                                       null, -- tasa
                                                       null, -- valor de tasa
                                                       'Pago de Interes Cupon Cta: '||v_nro_cuenta, --concepto
                                                       'N', -- emitir aviso
                                                       v_nro_secuencia, -- nro de secuencia
                                                       v_fec_actual);
                               if pag_cta.g_cod_error <> 0 then
                                   -- actualizacion con problemas
                                   v_cod_respuesta := '008';
                                   v_msj_respuesta := pag_cta.g_msj_error;
                               end if;

                         end if;
                      ELSIF p_tipo = 'C' then
                           lp_ins_bw_pag_ser(p_nro_cupon);
                           lp_ins_deb_operacion(p_nro_cupon, 'D');
                            if v_cod_respuesta = '000' then
                               lp_ins_deb_operacion(p_nro_cupon, 'C');
                            end if;
                      END IF;

                  END IF;    -- estado de cuenta cupon
               END IF;

         elsif p_cod_servicio = 660 AND v_cod_respuesta='000' then
                   v_concepto_aux :='PAGO DE CDA';
                   begin
                    Select nro_cuenta, cod_moneda, estado,
                           cod_modalidad, fec_vencimiento,
                           est_certificado,capital, nvl(sal_total,0)-nvl(sal_retenido,0)-nvl(sal_bloqueado,0)
                      into v_nro_cuenta, v_cod_moneda, v_est_cuenta,
                           v_tip_cuenta, v_fec_vencimiento,
                           v_est_certificado,v_capital, v_sal_disponible
                      from ah_cta_certificados
                     where serie = p_serie
                       and nro_certificado = to_number(p_nro_certificado)
                       and cod_moneda = p_cod_moneda
                      -- and est_batch not in ('A', 'T')
                       ;
                   exception
                     when no_data_found then
                         v_cod_respuesta := '024';
                         v_msj_respuesta := 'ERROR: No se ha encontrado el CDA';
                     when others then
                         v_cod_respuesta := '025';
                         v_msj_respuesta := sqlerrm;
                   end;

                             if v_cod_respuesta = '000'then
                               if v_est_cuenta not in ('V','P','S') then
                                  v_cod_respuesta := '018';
                                  v_msj_respuesta := 'ERROR: Cuenta no esta vencida. No se puede pagar.';
                                elsif v_est_certificado not in ('V') then
                                  v_cod_respuesta := '019';
                                  v_msj_respuesta := 'ERROR: Documento no se halla vencido. No se puede pagar.';
                                elsif v_importe > v_sal_disponible then -- Modificado para que permita pagos parciales en CDA
                                  v_cod_respuesta := '020';
                                  v_msj_respuesta := 'ERROR: El Importe del Documento no corresponde, importe mayor al saldo disponible.';
                                elsif v_est_cuenta = 'S' AND v_importe > v_sal_disponible then
                                  v_cod_respuesta := '021';
                                  v_msj_respuesta := 'ERROR: La cuenta tiene bloqueo de Saldo. No se permite Pago.';
                                end if;
                              end if;
                              v_cod_servicio := p_cod_servicio;
                              v_cod_modulo         :=3;    -- Caja
                              v_cod_modalidad      := 33;   -- Caja

                            -- Consulta nro de transaccion en los CDA
                            v_con_transaccion :=0;
                            begin
                              select nvl(count(m.nro_documento3),0)
                                into v_con_transaccion
                                from ge_movimientos m
                               where m.nro_documento =p_nro_certificado
                                 and m.nro_documento3=p_nro_transaccion;
                                 if nvl(v_con_transaccion,0)>0 then
                                   v_cod_respuesta := '022';
                                   v_msj_respuesta  :=  'Ya se encuentra ingresado el nro de transaccion ' || p_nro_transaccion;
                                 end if;
                            exception
                              when others then
                                  v_cod_respuesta := '023';
                                  v_msj_respuesta  :=  'Error: al consultar nro de transaccion ' || p_nro_transaccion;
                            end ;
                              if p_tipo='E' and v_cod_respuesta = '000' then
                                 v_cod_transaccion    := 329;  -- transaccion
                                 v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                             v_tip_cuenta,
                                                             v_cod_transaccion,
                                                             v_est_cuenta,
                                                             'D'); -- 'D'== DEBITO EN CUENTA
                                 if v_msj_respuesta is not null then
                                      v_cod_respuesta := '022';  -- la cuenta tiene impedimentos
                                 else
                                     v_msj_respuesta  := 'Operacion Confirmada'; -- sin errores
                                 end if;

                                 if v_cod_respuesta = '000' then

                                     Begin
                                         -- Débito
                                         lp_ins_bw_pag_ser(p_nro_certificado);
                                         lp_ins_deb_operacion(p_nro_certificado, 'D');
                                         if v_cod_respuesta ='000' then
                                            pag_cta.PR_SET_NRO_DOCUMENTO3(p_nro_transaccion);
                                             v_nro_secuencia := v_nro_secuencia + 1;
                                            pag_cta.pr_act_operacion(v_cuenta_cn,
                                                                     v_hor_actual,
                                                                     'C', -- debito o credito
                                                                     p_cod_moneda,
                                                                     v_importe,
                                                                     v_cod_transaccion,
                                                                     602,
                                                                     p_nro_certificado,
                                                                     null, -- cotizacion
                                                                     v_cod_oficina,
                                                                     v_cod_modulo,
                                                                     v_cod_modalidad,
                                                                     null, -- tasa
                                                                     null, -- valor de tasa
                                                                     'Pago de CDA Cuenta '||v_nro_cuenta, --concepto
                                                                     'N', -- emitir aviso
                                                                     v_nro_secuencia, -- nro de secuencia
                                                                     v_fec_actual);
                                             if pag_cta.g_cod_error <> 0 then
                                                 -- actualizacion con problemas
                                                 v_cod_respuesta := '008';
                                                 v_msj_respuesta := pag_cta.g_msj_error;
                                             end if;
                                       END IF;

                                    exception
                                      when others then
                                          v_cod_respuesta := '023';
                                          v_msj_respuesta := 'Error credito cuenta '||v_cuenta_cn;
                                    END;
                                 END IF;
                              elsif p_tipo='C' and v_cod_respuesta = '000'  then
                                   v_cod_transaccion    := 329;  -- transaccion
                                   lp_ins_bw_pag_ser(p_nro_certificado);
                                   lp_ins_deb_operacion(p_nro_certificado, 'D');
                                   if v_cod_respuesta = '000' then
                                      lp_ins_deb_operacion(p_nro_certificado, 'C');
                                   end if;
                              end if;


         end if;
  END IF; -- verifica cod respuesta
 p_cod_respuesta := v_cod_respuesta;
 p_msj_respuesta := v_msj_respuesta;


exception
  when others then
       v_cod_respuesta := '027';
       v_msj_respuesta := 'ERROR: '||sqlerrm;
       p_cod_respuesta := v_cod_respuesta;
       p_msj_respuesta := v_msj_respuesta;

END;
-- procedimiento para llamar al API para reintentar pagos inconclusos
PROCEDURE pr_pro_reintento IS
  v_respuesta  TYP_POSTRESPUESTA;
  v_parametros ge_par_dinamicos.val_parametro%TYPE;
  v_url_retry      ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_RETRY'));
  v_url_gateway    ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_SOCK'));
  v_api_gateway    ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_API'));

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
BEGIN
  v_parametros := utl_lms.format_message('access_token=%s', v_api_gateway);
  v_respuesta  := fue_env_post(v_parametros, v_url_gateway || v_url_retry);
  lp_reg_operacion(v_url_gateway || v_url_retry, v_respuesta.error || '-' || v_respuesta.codigoError
                                                  || '-' || v_respuesta.status_code
                                                  || '-' || v_respuesta.descripcionRespuesta);
EXCEPTION
   WHEN OTHERS THEN
      lp_reg_operacion(v_url_gateway || v_url_retry, sqlerrm);
END;
procedure pr_obt_dat_tarjetas(p_nro_cuenta       in ta_cta_tarjetas.nro_cuenta%type,
                                p_nro_tarjeta      out ta_tarjetas.nro_tarjeta%type,
                                p_nro_documento    out ba_personas.nro_documento%type,
                                p_nom_embozar      out ta_tarjetas.nom_embozar%type,
                                p_des_modalidad    out ge_modalidades.descripcion%type,
                                p_moneda           out ta_cta_tarjetas.cod_moneda%type,
                                p_sal_pag_minimo   out ta_cta_tarjetas.sal_pag_minimo%type,
                                p_mto_pag_minimo   out ta_cta_tarjetas.mto_pag_minimo%type,
                                p_sal_ult_extracto out ta_cta_tarjetas.sal_ult_extracto%type,
                                p_deu_tot_actual   out ta_cta_tarjetas.sal_ult_extracto%type,
                                p_fec_ult_cierre   out ta_cta_tarjetas.fec_ult_cierre%type,
                                p_cod_modulo       out ta_cta_tarjetas.cod_modulo%type,
                                p_cod_modalidad    out ta_cta_tarjetas.cod_modalidad%type,
                                p_cod_oficina      out ta_cta_tarjetas.cod_oficina%type,
                                p_dia_mora         out ta_cta_tarjetas.dia_mora%type,
                                p_det_error        out ge_log_errores.det_error%type,
                                p_en_juicio        out ta_cta_tarjetas.en_juicio%type,
                                p_estado           out ta_cta_tarjetas.estado%type,
                                p_cod_error        out number,
                                p_respuesta        out varchar2) is

    v_det_error ge_log_errores.det_error%type;

  Begin
    SELECT p.nro_documento,
           c.nro_tarjeta,
           c.nom_embozar,
           d.descripcion,
           a.cod_moneda,
           a.sal_pag_minimo,
           a.mto_pag_minimo,
           a.sal_ult_extracto,
           (nvl(a.sal_facturar, 0) + nvl(a.sal_facturado, 0) +
           nvl(a.sal_financiado, 0) + nvl(a.sal_cuo_pendientes, 0)) deuda_actual,
           a.fec_ult_cierre,
           a.cod_modulo,
           a.cod_modalidad,
           a.cod_oficina,
           a.dia_mora,
           a.en_juicio,
           a.estado
      into p_nro_documento,
           p_nro_tarjeta,
           p_nom_embozar,
           p_des_modalidad,
           p_moneda,
           p_sal_pag_minimo,
           p_mto_pag_minimo,
           p_sal_ult_extracto,
           p_deu_tot_actual,
           p_fec_ult_cierre,
           p_cod_modulo,
           p_cod_modalidad,
           p_cod_oficina,
           p_dia_mora,
           p_en_juicio,
           p_estado
      FROM ge_modalidades  d,
           ta_tarjetas     c,
           ge_cta_clientes b,
           ta_cta_tarjetas a,
           ba_personas     p
     WHERE a.nro_cuenta = p_nro_cuenta
       AND a.nro_cuenta = b.nro_cuenta
       AND b.relacion = 'P'
       AND c.nro_cuenta = b.nro_cuenta
       AND c.vigente = 'S'
       AND p.cod_persona = b.cod_persona
       AND d.cod_modulo = a.cod_modulo
       AND d.cod_modalidad = a.cod_modalidad
       AND c.rel_tarjeta = 0;
    p_cod_error := 0;
    p_respuesta := 'OK';
  exception
    when no_data_found then
      p_cod_error := 1;
      p_respuesta := 'No existe cuenta ' || p_nro_cuenta;
      v_det_error := 'Cuenta: ' || p_nro_cuenta || ' Error: ' ||
                     p_respuesta;
      PRG_INS_LOG_PROGRAMAS('pag_ser.pr_obt_dat_tarjetas',
                            v_det_error,
                            null,
                            null);
    when others then
      p_cod_error := 2;
      p_respuesta := 'Error al recuperar datos de ' || p_nro_cuenta ||
                     ' - ' || sqlerrm;
      v_det_error := 'Cuenta: ' || p_nro_cuenta || ' Error: ' ||
                     p_respuesta;
      PRG_INS_LOG_PROGRAMAS('pag_ser.pr_obt_dat_tarjetas',
                            v_det_error,
                            null,
                            null);
end pr_obt_dat_tarjetas;

  procedure pr_cob_tarjeta(p_nro_cuenta    IN ta_tarjetas.nro_cuenta%TYPE,
                           p_importe       IN pr_cuotas.mto_capital%TYPE,
                           p_mon_bcp       IN VARCHAR2,
                           p_comprobante   ge_movimientos.referencia%type, --Identificador unico de transaccion
                           p_id_movimiento ge_movimientos.nro_documento2%type,
                           p_red_pago      IN NUMBER default null,
                           p_error         out number,
                           p_respuesta     out varchar2) IS
    v_cod_tra_padre      ge_movimientos.cod_tra_padre%TYPE := 250;
    v_cod_rubro          ge_movimientos.cod_rubro%TYPE;
    v_importe            NUMBER(16, 2); -- Variable para formatear el monto ingresado por el usuario.
    v_redondeo           NUMBER(3);
    v_cod_usuario        VARCHAR2(10) := upper(USER);
    v_concepto           ge_movimientos.concepto%TYPE;
    v_hora               ge_movimientos.hora%TYPE;
    r_gmovi              ge_movimientos%ROWTYPE;
    v_cod_ofi_origen     pr_movimientos_his.cod_ofi_origen%TYPE;
    v_cod_persona        ba_personas.cod_persona%TYPE;
    v_nro_secuencia      ge_movimientos.nro_secuencia%TYPE := 0;
    v_tipo               GE_TASAS.TIPO%TYPE;
    v_des_estado         ba_cod_referencias.significado%TYPE;
    v_cod_transaccion    ge_transacciones.cod_transaccion%TYPE;
    v_entidad            ba_cod_referencias.significado%TYPE := '';
    v_nom_parametro      ba_cod_referencias.significado%TYPE := '';
    v_existe             varchar2(1);
    v_nro_doc_cliente    ba_personas.nro_documento%TYPE := '0';
    v_hor_cobro          ge_movimientos.hora%TYPE;
    v_msj_error          varchar2(4000);
    v_mto_minimo         NUMBER(16, 2);
    v_red_pronet         ba_cod_referencias.val_minimo%TYPE;
    v_cod_ent_pronet     ge_entes.cod_ente%type;
    v_red_practipago     ba_cod_referencias.val_minimo%TYPE;
    v_red_infonet        ba_cod_referencias.val_minimo%TYPE;
    v_red_netel          ba_cod_referencias.val_minimo%TYPE;
    v_cod_ent_practipago ge_entes.cod_ente%type;
    v_cod_ent_infonet    ge_entes.cod_ente%type;
    v_cod_ent_netel      ge_entes.cod_ente%type;
    -----------------------------------------------------------------------------------------
    v_nro_tarjeta      ta_tarjetas.nro_tarjeta%type;
    v_nro_cuenta       ta_cta_tarjetas.nro_cuenta%type;
    v_nro_documento    ba_personas.nro_documento%type;
    v_nom_embozar      ta_tarjetas.nom_embozar%type;
    v_des_modalidad    ge_modalidades.descripcion%type;
    v_moneda           ta_cta_tarjetas.cod_moneda%type;
    v_sal_pag_minimo   ta_cta_tarjetas.sal_pag_minimo%type;
    v_mto_pag_minimo   ta_cta_tarjetas.mto_pag_minimo%type;
    v_sal_ult_extracto ta_cta_tarjetas.sal_ult_extracto%type;
    v_deu_tot_actual   ta_cta_tarjetas.sal_ult_extracto%type;
    v_fec_ult_cierre   ta_cta_tarjetas.fec_ult_cierre%type;
    v_cod_modulo       ta_cta_tarjetas.cod_modulo%type;
    v_cod_modalidad    ta_cta_tarjetas.cod_modalidad%type;
    v_cod_oficina      ta_cta_tarjetas.cod_oficina%type;
    v_dia_mora         ta_cta_tarjetas.dia_mora%type;
    v_det_error        ge_log_errores.det_error%type;
    v_cod_error        number;
    v_respuesta        varchar2(500);
    v_exi_cta          varchar2(1);
    v_en_juicio        ta_cta_tarjetas.en_juicio%TYPE;
    v_fec_actual       ge_movimientos.fecha%type;
    v_es_nocturno      varchar2(1);
    v_salida           varchar2(500);
    v_estado           ta_cta_tarjetas.estado%type;
    v_par_moneda       ba_monedas.cod_moneda%type;
    v_id_transaccion   ge_movimientos.referencia%type;
    v_cod_procesadora  ta_tipos.cod_ent_procesadora%TYPE;
  BEGIN
    if nvl(p_red_pago, 0) = 0 then
      p_error       := pag_ser.v_sin_datos;
      v_cod_retorno := pag_ser.v_sin_datos;
      p_respuesta   := 'Debe ingresar red de pago: ' || p_red_pago;
      return;
    end if;
    if nvl(p_importe, 0) = 0 then
      p_error       := pag_ser.v_sin_datos;
      v_cod_retorno := pag_ser.v_sin_datos;
      p_respuesta   := 'Debe ingresar el monto de la operacion: ' ||
                       p_importe;
      return;
    end if;
    if nvl(p_mon_bcp, 'x') = 'x' then
      p_error       := pag_ser.v_sin_datos;
      v_cod_retorno := pag_ser.v_sin_datos;
      p_respuesta   := 'Debe ingresar la moneda: ' || p_mon_bcp;
      return;
    end if;

    if nvl(p_nro_cuenta, 'x') = 'x' then
      p_error       := pag_ser.v_sin_datos;
      v_cod_retorno := pag_ser.v_sin_datos;
      p_respuesta   := 'Debe ingresar la cuenta - ' || p_nro_cuenta;
      return;
    end if;

    v_cod_transaccion := 978;

    v_red_pago := p_red_pago;
    v_concepto := 'Cobros Tarjeta ';

    BEGIN
      select 'S'
        into v_existe
        from ba_cod_referencias
       where dominio = 'TAR_COM_TRA_PAGSER'
         and val_minimo = v_red_pago;

      v_entidad := FUE_OBT_SIG_REFCODES('TAR_COM_TRA_PAGSER', v_red_pago);
    EXCEPTION
      WHEN no_data_found THEN
        p_error       := pag_ser.v_ent_incorrecta;
        v_cod_retorno := pag_ser.v_ent_incorrecta;
        p_respuesta   := 'No existe red de pago ' || v_red_pago;
        return;
    END;

    BEGIN
      SELECT 'S'
        INTO v_exi_cta
        FROM ba_personas a, ge_cta_clientes c, ta_cta_tarjetas s
       WHERE a.cod_persona = c.cod_persona
         AND c.nro_cuenta = s.nro_cuenta
         AND c.nro_cuenta = p_nro_cuenta
         AND c.relacion = 'P'
         AND s.estado not in ('C', 'V');
    EXCEPTION
      WHEN no_data_found THEN
        p_error       := pag_ser.v_tra_incorrecta;
        v_cod_retorno := pag_ser.v_tra_incorrecta;
        p_respuesta   := 'Cuenta inexistente ' || p_nro_cuenta;
        return;
    END;

    BEGIN
      SELECT val_minimo, abreviatura
        INTO v_red_pronet, v_cod_ent_pronet
        FROM ba_cod_referencias
       WHERE dominio = 'TAR_COM_TRA_PAGSER'
         AND significado = 'PRONET';
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Se debe configurar ' || 'PRONET';
    END;

    BEGIN
      SELECT val_minimo, abreviatura
        INTO v_red_practipago, v_cod_ent_practipago
        FROM ba_cod_referencias
       WHERE dominio = 'TAR_COM_TRA_PAGSER'
         AND significado = 'PRACTIPAGO';
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_retorno := pag_ser.v_err_proceso;
        v_des_retorno := 'Se debe configurar ' || 'PRACTIPAGO';
    END;

    if nvl(p_red_pago, 0) = to_number(v_red_pronet) then
      --> para pronet se guarda el nro de cuenta no hay id transaccio
      v_id_transaccion := p_nro_cuenta;
    else
      if nvl(p_comprobante, 'x') = 'x' then
        p_error       := pag_ser.v_sin_datos;
        v_cod_retorno := pag_ser.v_sin_datos;
        p_respuesta   := 'Debe ingresar el Id de la operacion - ' ||
                         p_comprobante;
        return;
      else
        v_id_transaccion := p_comprobante;
      end if;
    end if;

    v_concepto := v_concepto || v_entidad;
    -- Recuperar la cuenta, esto es, por si se ingresa C.I. o Nro. Cuenta indistintamente
    -- como parametro.

    --Controla que el pago sea mayor al minimp
    v_importe    := p_importe;
    v_par_moneda := it.fue_obt_mon_bcp(to_number(p_mon_bcp));
    if v_cod_retorno = pag_ser.v_cod_aprobado then
      pr_obt_dat_tarjetas(p_nro_cuenta,
                          v_nro_tarjeta,
                          v_nro_documento,
                          v_nom_embozar,
                          v_des_modalidad,
                          v_moneda,
                          v_sal_pag_minimo,
                          v_mto_pag_minimo,
                          v_sal_ult_extracto,
                          v_deu_tot_actual,
                          v_fec_ult_cierre,
                          v_cod_modulo,
                          v_cod_modalidad,
                          v_cod_oficina,
                          v_dia_mora,
                          v_det_error,
                          v_en_juicio,
                          v_estado,
                          v_cod_error,
                          v_respuesta);

      if v_cod_error != 0 then
        v_cod_retorno := pag_ser.v_cta_incorrecta;
        v_des_retorno := 'Error al obtener cta ' || p_nro_cuenta;
        p_respuesta   := v_respuesta;
      end if;

      if nvl(v_importe, 0) > 0 and v_cod_retorno = pag_ser.v_cod_aprobado then
        if v_importe < v_mto_pag_minimo then
          p_error       := pag_ser.v_err_mto_minimo;
          v_cod_retorno := pag_ser.v_err_mto_minimo;
          p_respuesta   := 'Monto ingresado debe ser mayor o igual al pago minimo : ' ||
                           v_mto_pag_minimo;
          return;
        end if;
      else
        p_error       := pag_ser.v_err_mto_minimo;
        v_cod_retorno := pag_ser.v_err_mto_minimo;
        p_respuesta   := 'Monto ingresado debe ser mayor a cero ';
        return;
      end if;

      IF v_par_moneda != pag_gen.fu_obt_mon_local THEN
        p_error       := pag_ser.v_mon_incorrecta;
        v_cod_retorno := pag_ser.v_mon_incorrecta;
        p_respuesta   := 'Moneda incorrecta ' || v_par_moneda;
        return;
      END IF;
      IF v_par_moneda <> v_moneda THEN
        p_error       := pag_ser.v_mon_incorrecta;
        v_cod_retorno := pag_ser.v_mon_incorrecta;
        p_respuesta   := 'Moneda incorrecta ' || v_par_moneda;
        return;
      END IF;

      v_salida := fuj_ver_impedimentos(p_nro_cuenta,
                                       v_cod_modalidad,
                                       v_cod_transaccion,
                                       v_estado,
                                       'C'); -- 'C'== CREDITO
      if v_salida is not null then
        v_cod_retorno := pag_ser.v_tra_incorrecta;
        v_des_retorno := 'Error en la cuenta ' || p_nro_cuenta;
        p_respuesta   := v_salida;
      end if;
    end if;

    IF v_red_pago = v_red_pronet and v_cod_retorno = pag_ser.v_cod_aprobado THEN
      if v_cod_ent_pronet is not null then
        if v_moneda = 'GS' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_pronet, 'PAG_TAR_RUBRO');
        end if;
      end if;
    ELSIF v_red_pago = v_red_practipago THEN
      if v_cod_ent_practipago is not null then
        if v_moneda = 'GS' THEN
          v_cod_rubro := fug_obt_parentes(v_cod_ent_practipago,
                                          'PAG_TAR_RUBRO');

        end if;
      end if;

    END IF;

    BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := v_cod_modulo;
    END;

    if pae_cnf.fu_obt_est_modulo(3) != 2 then
      p_error     := v_cie_diario;
      p_respuesta := 'En proceso de cierre';
      return;
    end if;

    IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
      begin
        savepoint pago;
        v_hora           := to_char(SYSDATE, 'hh24:mi:ss');
        v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);
        v_hor_cobro      := v_hor_actual;
        v_fec_actual     := pag_cal.FU_OBT_FEC_ACTUAL(3);
        v_hor_cobro      := fug_obt_hor_disponible(v_fec_actual,
                                                   v_hor_actual,
                                                   user,
                                                   'N');

        lp_ver_horario;

        pag_cta.pr_set_referencia(v_id_transaccion);
        pag_cta.pr_set_nro_documento2(p_id_movimiento);
        pag_cta.pr_act_operacion(p_nro_cuenta,
                                 v_hor_cobro,
                                 'C', -- Credito
                                 v_par_moneda,
                                 p_importe,
                                 v_cod_tra_padre,
                                 v_cod_transaccion, -- trans. hijo de efectivo
                                 p_red_pago,
                                 null, -- cotizacion
                                 v_cod_ofi_origen,
                                 v_cod_modulo,
                                 v_cod_modalidad,
                                 null, -- tasa
                                 null, -- valor de tasa
                                 v_concepto, --concepto
                                 'N', -- emitir aviso
                                 v_nro_secuencia, -- nro de secuencia
                                 v_fec_actual);

        IF pag_cta.G_COD_ERROR <> 0 THEN
          v_cod_retorno := pag_ser.v_err_proceso;
          v_des_retorno := 'Error en el proceso';
          p_respuesta   := pag_cta.G_MSJ_ERROR;
          rollback to pago;
        END IF;

        --
        IF v_cod_retorno = pag_ser.v_cod_aprobado THEN

          IF v_cod_rubro is not null then
            -- Movimiento contra rubro contable --
            v_nro_secuencia       := nvl(v_nro_secuencia, 0) + 1;
            r_gmovi.cod_usuario   := user;
            r_gmovi.hora          := v_hor_cobro;
            r_gmovi.fecha         := v_fec_actual;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_modulo    := v_cod_modulo;
            r_gmovi.cod_modalidad := v_cod_modalidad;
            r_gmovi.cod_oficina   := v_cod_oficina;
            r_gmovi.cod_moneda    := v_par_moneda;
            r_gmovi.fec_valor     := trunc(sysdate);
            r_gmovi.cod_tra_padre := v_cod_tra_padre;
            r_gmovi.cod_mod_padre := v_cod_modulo;
            r_gmovi.cod_mad_padre := v_cod_modalidad;
            --Transaccion COBRO DE CUENTA CONTABLE
            r_gmovi.cod_transaccion := 842;
            r_gmovi.monto           := v_importe;
            r_gmovi.nro_documento   := p_red_pago;
            r_gmovi.referencia      := v_id_transaccion;
            r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Cobro de cuenta ' || p_nro_cuenta;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.nro_documento2  := p_id_movimiento;
            --Entra el rubro contable
            r_gmovi.cod_rubro     := v_cod_rubro;
            r_gmovi.tip_mov_rubro := 'D';

            begin

              pag_gen.pr_ins_ge_movimiento(r_gmovi, pag_ser.v_es_mov_noc);

            exception
              when others then
                v_cod_retorno := pag_ser.v_err_proceso;
                v_des_retorno := 'Error en el proceso';
                p_respuesta   := DBMS_UTILITY.format_error_backtrace || ' ' ||
                                 DBMS_UTILITY.format_error_stack;
                rollback to pago;
            end;
          ELSIF v_cod_rubro is null then
            v_cod_retorno := pag_ser.v_err_proceso;
            v_des_retorno := 'Rubro no definido para ente ' ||
                             nvl(v_cod_ent_practipago, v_cod_ent_pronet);
            rollback to pago;
          END IF;
        END IF;

        if v_cod_retorno = pag_ser.v_cod_aprobado then
          --Verifico la procesadora para insertar el cobro en la tabla correspondiente
          v_cod_procesadora := fut_obt_procesadora(p_nro_cuenta);
          IF v_cod_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD') THEN
            INSERT INTO ta_cobros
              (nro_cuenta,
               nro_tarjeta,
               nro_cta_debito,
               fec_proceso,
               monto,
               estado,
               fec_valor,
               observacion,
               hora,
               cod_usuario,
               dia_mora,
               tipo,
               red_pago)
            VALUES
              (p_nro_cuenta,
               v_nro_tarjeta,
               NULL,
               v_fec_actual,
               v_importe,
               'P',
               v_fec_actual,
               v_concepto,
               --v_hor_actual,
               v_hor_cobro,
               USER,
               v_dia_mora,
               'P',
               v_red_pago);
        ELSIF v_cod_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL') THEN
          INSERT INTO ta_cobros_gp
            (nro_cuenta,
             nro_tarjeta,
             nro_cta_debito,
             fec_proceso,
             monto,
             estado,
             fec_valor,
             observacion,
             hora,
             cod_usuario,
             dia_mora,
             tipo,
             red_pago,
             canal)
          VALUES
            (p_nro_cuenta,
             v_nro_tarjeta,
             NULL,
             v_fec_actual,
             v_importe,
             'P',
             v_fec_actual,
             v_concepto,
             --v_hor_actual,
             v_hor_cobro,
             USER,
             v_dia_mora,
             'P',
             v_red_pago,
             'B');--Boca de cobranzas
          END IF;
        end if;
      exception
        when others then
          v_cod_retorno := pag_ser.v_err_proceso;
          v_des_retorno := 'Error en el proceso';
          p_respuesta   := DBMS_UTILITY.format_error_backtrace || ' ' ||
                           DBMS_UTILITY.format_error_stack;
          rollback to pago;
      end;
    END IF;
    p_error     := v_cod_retorno;
    p_respuesta := nvl(p_respuesta, v_des_retorno);
    if v_cod_retorno != pag_ser.v_cod_aprobado then
      v_det_error := 'Red de pago: ' || p_red_pago || ' ID Transaccion: ' ||
                     v_id_transaccion || ' Cuenta: ' || p_nro_cuenta ||
                     ' Monto: ' || p_importe || ' ' || p_mon_bcp ||
                     ' Error: Cod. ' || v_cod_retorno || ' ' || p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAG_SER.PR_COB_TARJETA',
                            v_det_error,
                            null,
                            p_nro_cuenta);

    end if;

  exception
    when others then
      v_cod_retorno := pag_ser.v_err_proceso;
      v_des_retorno := 'Error en el proceso';
      p_error       := v_cod_retorno;
      p_respuesta   := DBMS_UTILITY.format_error_backtrace || ' ' ||
                       DBMS_UTILITY.format_error_stack;
      v_det_error   := 'Red de pago: ' || p_red_pago || ' ID Transaccion: ' ||
                       v_id_transaccion || ' Cuenta: ' || p_nro_cuenta ||
                       ' Monto: ' || p_importe || ' ' || p_mon_bcp ||
                       ' Error: Cod. ' || v_cod_retorno || ' ' ||
                       p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAG_SER.PR_COB_TARJETA',
                            v_det_error,
                            null,
                            p_nro_cuenta);

END pr_cob_tarjeta;


PROCEDURE pr_rev_cob_tarjeta(p_id_transaccion ge_movimientos.referencia%type,
                             p_id_mov         ge_movimientos.nro_documento2%type,
                             p_red_pago       ge_movimientos.nro_documento%type,
                             p_error          out number,
                             p_respuesta      out varchar2) is
 v_fecha         ge_movimientos.fecha%type;
 v_hora          ge_movimientos.hora%type;
 v_cod_usuario   ge_movimientos.cod_usuario%type;
 v_cod_modulo    ge_movimientos.cod_modulo%type;
 v_cod_modalidad ge_movimientos.cod_modalidad%type;
 v_cod_tra_padre ge_movimientos.cod_tra_padre%type;
 v_hor_actual    varchar2(10) := to_char(SYSDATE, 'HH24:MI:SS');
 v_nro_cuenta    ge_movimientos.nro_cuenta%type;
 v_monto         ge_movimientos.monto%type;
 v_nro_documento ge_movimientos.nro_documento%type;
 v_det_error     ge_log_errores.det_error%type;
begin
 p_error     := 00;
 p_respuesta := 'Operacion exitosa';

 begin
   select ge.fecha,
          ge.hora,
          ge.cod_usuario,
          ge.cod_modulo,
          ge.cod_modalidad,
          ge.cod_tra_padre,
          ge.nro_cuenta,
          ge.monto,
          ge.nro_documento
     into v_fecha,
          v_hora,
          v_cod_usuario,
          v_cod_modulo,
          v_cod_modalidad,
          v_cod_tra_padre,
          v_nro_cuenta,
          v_monto,
          v_nro_documento
     from ge_movimientos ge
    where ge.nro_documento2 = p_id_mov
      and ge.referencia = p_id_transaccion
      and ge.nro_documento = p_red_pago
      and ge.reversado = 'N'
      and ge.nro_cuenta is not null;
 EXCEPTION
   WHEN no_data_found THEN
     p_error     := 01;
     p_respuesta := 'Operación inexistente.';

   WHEN OTHERS THEN
     p_error     := 02;
     p_respuesta := 'ERROR. Al obtener datos de la reversion ';
 END;
 savepoint reversion;

 if v_cod_retorno = 00 then
   /*reversion de cobro*/
   prg_rev_operacion(v_fecha,
                     v_hora,
                     v_cod_usuario,
                     v_cod_modulo,
                     v_cod_modalidad,
                     v_cod_tra_padre,
                     user,
                     v_hor_actual,
                     'N',
                     'Reversión.Pag.Tarjeta a la cuenta : ' ||
                     v_nro_cuenta,
                     null);

   /*actualiza a reversado el cobro*/
   update ta_cobros ta
      set ta.tipo = 'R'
    where ta.nro_cuenta = v_nro_cuenta
      and ta.fec_proceso = v_fecha
      and ta.hora = v_hora
      and ta.red_pago = p_red_pago;
 end if;

exception
 when others THEN
   rollback to reversion;
   p_error     := 03;
   p_respuesta := 'Error en el proceso de reversion';
   v_det_error := 'Red de pago: ' || p_red_pago || ' ID Transaccion: ' ||
                  p_id_transaccion || ' Cuenta: ' || v_nro_cuenta ||
                  ' Monto: ' || v_monto || ' Error: Cod. ' || p_error || '-' ||
                  v_det_error;
   PRG_INS_LOG_PROGRAMAS('PAG_SER.PR_REV_COB_TARJETA',
                         v_det_error,
                         null,
                         v_nro_cuenta);
END pr_rev_cob_tarjeta;

END pag_ser;
/

