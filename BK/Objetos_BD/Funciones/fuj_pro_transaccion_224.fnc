CREATE OR REPLACE FUNCTION IT."FUJ_PRO_TRANSACCION_224" (
      p_nro_operacion   in varchar2,   -- Nro de referencia de la operacion
      p_nro_caj_actual  in varchar2,
      p_nro_caja        in varchar2,   -- Nro de Caja
      p_nro_boleta      in varchar2 default null,
      p_cod_moneda      in varchar2 default null,   -- Moneda
     -- p_tip_operacion in varchar2 default null, -- No recibe mas como parametro la operacion, solo se 
                                                  -- va usar para el ingreso del sobrante. 30/08/2011 VV.                               
      p_monto in number default null,
      p_concepto in varchar2 default null)  --Monto de la Operacion--
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo ge_movimientos.cod_modulo%type       := 9;   -- Caja
  v_cod_modalidad ge_movimientos.cod_modalidad%type := 91;  -- Caja
  v_cod_mod_cta ge_movimientos.cod_modulo%type      := null;
  v_cod_mad_cta ge_movimientos.cod_modalidad%type   := null;
  v_cod_transaccion ge_movimientos.cod_transaccion%type := 224;        -- Transaccion
  v_cod_tra_regularizacion ge_movimientos.cod_transaccion%type := 232; -- Transaccion--
  v_cod_tra_hijo ge_movimientos.cod_transaccion%type := null; -- Transaccion--
  --
  v_cod_oficina ba_oficinas.cod_oficina%type;                   -- oficina de la caja
  v_cod_usuario ba_usuarios.cod_usuario%type := upper(user); -- usuario
  --
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  --
  v_monto             number := to_number(p_monto); -- importe de la transf
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(2000) := 'Operacion confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D';  -- credito para la caja (egreso)
  v_tip_monto     varchar2(01) := 'E';  -- efectivo
  v_nro_boleta    cj_movimientos.nro_documento%type;
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  r_gmovi         ge_movimientos%rowtype;
  v_concepto      ge_movimientos.concepto%type := null;
  v_est_cuenta     ge_cuentas.estado%TYPE;
  v_sal_disponible ge_movimientos.monto%TYPE;
  v_procesa        VARCHAR2(1);
  v_rol_operacion  VARCHAR2(1) := 'S';
  v_tip_operacion  VARCHAR2(1) := 'N'; -- Solo va a permitir cargar un nuevo sobrante. Remplaza al parametro.
  v_sal_sobrante   cj_sobrantes.saldo%TYPE := 0;
  v_nro_sobrante   cj_sobrantes.nro_sobrante%TYPE;
  v_err_regulacion VARCHAR2(1);
  v_cta_sobrante   ge_movimientos.nro_cuenta%TYPE;
   -- C.D. Fase III--
  v_tip_ope_riesgo  ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido		ge_mov_autorizaciones.nro_pedido%type; 
  -- Procedimiento interno para generar movimiento de transfrencia
  procedure lp_gen_transaccion (p_estado varchar2) is
  begin
      -- Actualizo el control de caja origen
      if p_estado <> 'P' then -- C.D.Fase III
        if v_tipo = 'D' then --Se suma al saldo--
           update cj_controles
              set sal_actual = nvl(sal_actual,0) + nvl(v_monto,0),
                  tot_debitos = nvl(tot_debitos,0) + nvl(v_monto,0),
                  can_debitos = nvl(can_debitos,0) + 1,
                  estado = 1 -- abierto
            where nro_caja = to_number(p_nro_caja)
              and cod_moneda = p_cod_moneda
              and fecha = v_fec_caja;
        else --C-Se resta al saldo--
           update cj_controles
              set sal_actual = nvl(sal_actual,0) - nvl(v_monto,0),
                  tot_creditos = nvl(tot_creditos,0) + nvl(v_monto,0),
                  can_creditos = nvl(can_creditos,0) + 1,
                  estado = 1 -- abierto
            where nro_caja = to_number(p_nro_caja)
              and cod_moneda = p_cod_moneda
              and fecha = v_fec_caja;
        end if;
      end if;
      -- genero el movimiento para la caja origen
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, cod_rubro, monto, tip_monto, tipo,
          nro_doc_referencia, estado )-- C.D.Fase III
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_transaccion,v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          v_nro_boleta,
          v_tip_operacion,
          v_monto,v_tip_monto /* efectivo */, v_tipo,
          null, p_estado); /* es credito */
      -- Se registra en el nuevo esquema de Sobrantes
      IF v_tip_operacion = 'N' THEN
         SELECT s_nro_sobrante.nextval INTO v_nro_sobrante FROM dual;
         INSERT INTO cj_sobrantes
            (nro_sobrante, fecha, hora, cod_usuario, cod_oficina, nro_caja, nro_cuenta, cod_moneda,
             monto, saldo, estado)
         VALUES
            (v_nro_sobrante, v_fec_actual, v_hor_actual, v_cod_usuario, v_cod_oficina,
             to_number(p_nro_caja), v_cta_sobrante, p_cod_moneda, v_monto, v_monto, decode(p_estado,'P', 'P', 'A')); /*Dejar en Pendiente. C.D.Fase III*/
      ELSE
         v_err_regulacion := fuj_act_sal_cajas(v_nro_sobrante, p_monto, v_cta_sobrante, p_cod_moneda, v_cod_oficina);
         IF nvl(v_err_regulacion, 'S') <> 'N' THEN
               v_cod_respuesta := '006'; -- error
               v_msj_respuesta := 'Error al actualizar el saldo del Sobrante';
         END IF;
      END IF ;
  end lp_gen_transaccion;
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; 
       PAE_CNF.G_COD_MODULO:=v_cod_modulo;
 END;
   BEGIN
      SELECT 'S'
        INTO v_rol_operacion
        FROM ba_usu_roles a
       WHERE a.cod_rol = 'REG_SOB_CAJA'
         AND a.cod_usuario = v_cod_usuario;
   EXCEPTION
      WHEN OTHERS THEN
         v_rol_operacion := 'N';
   END;
 -- Valido la moneda y el monto de cierre
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro.de Boleta.';
 elsif p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Moneda.';
 elsif v_tip_operacion is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Tipo de Operacion.';
 elsif p_monto is null or v_monto <= 0 then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Monto de la Operacion.';
 elsif p_concepto is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Concepto.';
  -- ELSIF v_rol_operacion = 'N' AND p_tip_operacion <> 'N' THEN
   ELSIF  v_tip_operacion <> 'N' THEN
      v_cod_respuesta := '001'; -- error
      --v_msj_respuesta := 'ERROR: No tiene Autorizacion para Realizar la Operacion.';
      v_msj_respuesta := 'ERROR: No se puede Realizar la Operacion.';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 if v_cod_respuesta = '000' then -- no hubo errores
    if v_tip_operacion = 'N' then
       v_cod_tra_hijo := v_cod_transaccion;
       v_tipo := 'D';  --Debito Contable para la caja (Ingreso)
    else --R-Regularizacion--
       v_cod_tra_hijo := v_cod_tra_regularizacion;
       v_tipo := 'C';  --Credito Contable para la caja (Egreso)
         BEGIN
            SELECT (c.saldo - v_monto), c.nro_sobrante
              INTO v_sal_sobrante, v_nro_sobrante
              FROM cj_sobrantes c
             WHERE c.nro_caja = p_nro_caja
               AND c.fecha = v_fec_actual
               AND c.estado = 'A'
               AND c.nro_sobrante = (SELECT MIN(n.nro_sobrante)
                                       FROM cj_sobrantes n
                                      WHERE n.fecha = v_fec_actual
                                        AND n.nro_caja = p_nro_caja
                                        AND n.estado = 'A'); 

            IF v_sal_sobrante < 0 THEN
               v_cod_respuesta := '006'; -- error
               v_msj_respuesta := 'ERROR: Monto ingresado mayor al saldo.';
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               v_cod_respuesta := '006'; -- error
               v_msj_respuesta := 'ERROR: Registro de Sobrante no encontrado.';
         END;

    end if;
    -- Obtengo los datos de la caja ---------------------------------------
    prj_obt_datos_caja(p_nro_caja,
                       p_cod_moneda,
                       v_cod_oficina,
                       v_fec_caja,
                       v_estado,
                       v_sal_actual,
                       v_sal_cheques,
                       'N'); -- para que no valide el responsable de la caja
    if v_estado = -1 then
          v_cod_respuesta := '006'; -- error, no existe registro de caja
          v_msj_respuesta := 'Caja inexistente!!';
    elsif v_estado in (0,2) then
          v_cod_respuesta := '004'; -- error
          v_msj_respuesta := 'Realice la Apertura de Caja previamente';
    elsif v_fec_caja <> v_fec_actual then
          v_cod_respuesta := '005'; -- error
          v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
    elsif v_sal_actual < v_monto and v_tipo = 'C' then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Caja no tiene saldo para esta Operacion';
    end if;
    -- verifico los datos de la caja destino
    If p_nro_boleta is not null then
       if v_cod_respuesta = '000' then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              p_cod_moneda,
                              p_nro_boleta,
                              v_cod_respuesta,
                              v_msj_respuesta);
    end if;
 End if;
    if v_cod_respuesta = '000' then
              v_nro_boleta := to_number(p_nro_boleta);
              -- Asigno el nro de caja a los movimientos
              pag_cta.pr_nro_caja(to_number(p_nro_caja));
              -- Verifico el Monto Riesgo. C.D.Fase III --
                PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                       v_hor_actual,
                                       v_cod_usuario,
                                       v_cod_transaccion, -- transacción padre 
                                       v_cod_modulo,      -- Módulo
                                       v_cod_modalidad,   -- Modalidad
                                       null,-- p_nro_cuenta,      -- Nro_cuenta
                                       null,-- v_cod_persona,     -- Persona
                                       v_tip_ope_riesgo,   -- Tip_operacion 
                                       v_monto,         -- Monto
                                       null,              -- Número de Documento
                                       p_cod_moneda,      -- Moneda
                                       null,              -- Cotización                       
                                       v_nro_pedido); 
               if nvl(v_nro_pedido,0) > 0 then
                 v_est_movimiento := 'P'; 
                 pag_cta.PR_SET_EST_MOVIMIENTO('P');
               else
                 v_est_movimiento := 'N'; 
                  pag_cta.PR_SET_EST_MOVIMIENTO('N');
               end if; 
              
              -- Acualizo la cuenta con el efectivo depositado
              v_nro_secuencia := 0;

              v_cta_sobrante    := fug_obt_pardinamico('NRO_CTA_SOB_CAJA', NULL, NULL, p_cod_moneda,v_cod_oficina);

              if v_monto > 0 then
                 if v_tip_operacion = 'R' then
                    v_concepto := p_concepto||'(REGUL)';
              else
                    v_concepto := p_concepto;
              end if;
            -- Verifica si esta la cuenta puede realizar el D/C
            pag_cta.pr_ver_operacion(v_cta_sobrante, v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
                                     'C', p_cod_moneda, v_monto, v_cod_oficina, v_cod_mod_cta,
                                     v_cod_mad_cta, v_est_cuenta, v_sal_disponible, v_procesa,
                                     v_cod_tra_hijo);

            IF v_procesa = 'N' THEN
               v_cod_respuesta := '006'; -- error
               v_msj_respuesta := 'Cuenta Operativa sin saldo para operacion';
            ELSE
               IF v_cod_respuesta = '000' THEN
                  v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
                  --generar movimiento, crédito a la cuenta operativa
                  pag_cta.pr_act_operacion(v_cta_sobrante, v_hor_actual, 'C', p_cod_moneda,
                                           v_monto, v_cod_transaccion,
                                           --COD_TRA_PADRE
                                           v_cod_tra_hijo,
                                           -- COD_TRA_HIJO
                                           v_nro_boleta,
                                           --Nro de Documento,
                                           NULL,
                                           --COTIZACION
                                           v_cod_oficina,
                                           --cod_ofi_origen
                                           v_cod_modulo,
                                           --cod_mod_padre
                                           v_cod_modalidad,
                                           --cod_mad_padre
                                           NULL,
                                           --cod_tasa
                                           NULL,
                                           --val_tasa
                                           'Sobrante Caja ' || to_number(p_nro_caja), 'N',
                                           --emi_aviso
                                           v_nro_secuencia, v_fec_actual/*, null, null, null, v_est_movimiento*/); -- C.D.Fase III
                                           

               END IF;
            END IF;
          end if;
          -- operacion valida, se puede procesar
         IF pag_cta.fu_obt_cod_error() <> 0 THEN
            v_cod_respuesta := '006'; -- error
            v_msj_respuesta := pag_cta.g_msj_error;
         ELSE
           -- C.D.Fase III --
           if nvl(v_nro_pedido,0) > 0 then
             lp_gen_transaccion('P');
           else
             lp_gen_transaccion('N');
            end if;
         end if;
end if;
end if;
if nvl(v_nro_pedido,0) > 0 then -- C.D.Fase III 
  v_cod_respuesta := '000';
  v_msj_respuesta := 'Se ha generado el Pedido de Autorización Nro.:'||v_nro_pedido;
end if; 
 --Impresion de Comprobante--
 --if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
 --   v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso'||'~'||
 --   fuj_imp_comprobante_204(v_nro_boleta,
 --                           v_cod_oficina,
 --                           p_nro_caja);
 --   v_cod_respuesta := 'IMP';
 --end if;
 /* armo finalmente el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta;
  return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_224;
/

