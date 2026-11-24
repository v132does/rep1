CREATE OR REPLACE FUNCTION IT."FUJ_PRO_TRANSACCION_223" (
      p_nro_operacion   in varchar2,   -- Nro de referencia de la operacion
      p_nro_caj_actual  in varchar2, 
      p_nro_caja        in varchar2,   -- Nro de Caja
      p_nro_boleta      in varchar2 default null,
      p_cod_moneda      in varchar2 default null,   -- Moneda
      p_tip_operacion in varchar2 default null,
      p_monto in number default null,
      p_concepto in varchar2 default null)  --Monto de la Operacion--
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 223;        -- Transaccion
  v_cod_tra_regularizacion number(3) := 231; -- Transaccion
  v_cod_tra_hijo number(4) := null;        -- Transaccion
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
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
  v_tipo          varchar2(01) := 'C';  -- credito para la caja (egreso)
  v_tip_monto     varchar2(01) := 'E';  -- efectivo
  v_nro_boleta    cj_movimientos.nro_documento%type;
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  r_gmovi         ge_movimientos%rowtype;
  v_concepto      ge_movimientos.concepto%type := null;
    -- C.D. Fase III--
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido		  ge_mov_autorizaciones.nro_pedido%type; 
  -- Procedimiento interno para generar movimiento de transfrencia
  procedure lp_gen_transaccion (p_estado varchar2)  is
  begin
      -- Actualizo el control de caja origen
      if p_estado <> 'P'then -- C.D.Fase III
        if v_tipo = 'C' then --Se resta el saldo--
           update cj_controles
              set sal_actual = nvl(sal_actual,0) - nvl(v_monto,0),
                  tot_creditos = nvl(tot_creditos,0) + nvl(v_monto,0),
                  can_creditos = nvl(can_creditos,0) + 1,
                  estado = 1 -- abierto
            where nro_caja = to_number(p_nro_caja)
              and cod_moneda = p_cod_moneda
              and fecha = v_fec_caja;
        else --D-Se suma al saldo--
           update cj_controles
              set sal_actual = nvl(sal_actual,0) + nvl(v_monto,0),
                  tot_debitos = nvl(tot_debitos,0) + nvl(v_monto,0),
                  can_debitos = nvl(can_debitos,0) + 1,
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
          nro_doc_referencia, estado)-- C.D.Fase III
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          v_nro_boleta,
          p_tip_operacion,
          v_monto,v_tip_monto /* efectivo */, v_tipo,
          null, p_estado); /* es credito */
  end lp_gen_transaccion;
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda y el monto de cierre
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro.de Boleta.';
 elsif p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Moneda.';
 elsif p_tip_operacion is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Tipo de Operacion.';
 elsif p_monto is null or v_monto <= 0 then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Monto de la Operacion.';
 elsif p_concepto is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Concepto.';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 if v_cod_respuesta = '000' then -- no hubo errores
    if p_tip_operacion = 'N' then
       v_cod_tra_hijo := v_cod_transaccion;
       v_tipo := 'C';  -- Credito Contable para la caja (Egreso)
    else --R-Regularizacion--
       v_cod_tra_hijo := v_cod_tra_regularizacion;
       v_tipo := 'D';  -- Debito Contable para la caja (Ingreso)
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
                                       v_tip_operacion,   -- Tip_operacion 
                                       v_monto,         -- Monto
                                       null,              -- Número de Documento
                                       p_cod_moneda,      -- Moneda
                                       null,              -- Cotización                       
                                       v_nro_pedido); 
               if v_nro_pedido > 0 then
                 v_est_movimiento := 'P'; 
               else
                 v_est_movimiento := 'N'; 
               end if; 
              -- Acualizo la cuenta con el efectivo depositado
              v_nro_secuencia := 0;
              if v_monto > 0 then
                 if p_tip_operacion = 'R' then
                    v_concepto := p_concepto||'(REGUL)';
                 else
                    v_concepto := p_concepto;
                 end if;
                  --generar movimiento
                  v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                  r_gmovi.cod_usuario     := v_cod_usuario;
                  r_gmovi.hora            := v_hor_actual;
                  r_gmovi.fecha           := v_fec_actual;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.cod_modulo      := v_cod_modulo;
                  r_gmovi.cod_modalidad   := v_cod_modalidad;
                  r_gmovi.cod_oficina     := v_cod_oficina;
                  r_gmovi.cod_moneda      := p_cod_moneda;
                  r_gmovi.fec_valor       := v_fec_actual;
                  r_gmovi.cod_tra_padre   := v_cod_transaccion;
                  r_gmovi.cod_mod_padre   := v_cod_modulo;--9
                  r_gmovi.cod_mad_padre   := v_cod_modalidad;--91
                  r_gmovi.nro_caja        := to_number(p_nro_caja);
                  r_gmovi.cod_transaccion := v_cod_tra_hijo;
                  r_gmovi.monto           := v_monto;
                  r_gmovi.nro_documento   := v_nro_boleta;
                  --r_gmovi.nro_documento2  := to_number(p_nro_caj_destino);
                  r_gmovi.nro_documento3  := null;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := v_concepto;
                  r_gmovi.referencia      := p_tip_operacion;
                  -- C.D.Fase III
                  --r_gmovi.estado          := 'N';
                  r_gmovi.estado          := v_est_movimiento;
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_ofi_origen  := v_cod_oficina;
                  r_gmovi.cod_rubro       := NULL;
                  r_gmovi.nro_cuenta      := null;
                  r_gmovi.tip_mov_rubro   := NULL;
                  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
          end if;
          -- operacion valida, se puede procesar
          if nvl(v_nro_pedido,0) > 0 then
            lp_gen_transaccion('P');
          else
             lp_gen_transaccion('N');
          end if;
    end if;
 end if;
 --Impresion de Comprobante--
 --if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
 --   v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso'||'~'||
 --   fuj_imp_comprobante_204(v_nro_boleta,
 --                           v_cod_oficina,
 --                           p_nro_caja);
 --   v_cod_respuesta := 'IMP';
 --end if;
 if v_nro_pedido > 0 then -- C.D.Fase 
   v_cod_respuesta := '000';
   v_msj_respuesta:= 'Se ha generado un Pedido de Autorización Nro.:'||v_nro_pedido;
 end if;
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
end FUJ_PRO_TRANSACCION_223;
/

