CREATE OR REPLACE PROCEDURE it.prj_obt_car_segmento(p_nro_cuenta IN VARCHAR2,
                                                    p_cod_moneda IN VARCHAR2,
                                                    p_monto      IN NUMBER,
                                                    p_respuesta  OUT VARCHAR2,
                                                    p_val_cargo  OUT NUMBER,
                                                    p_val_tasa   OUT NUMBER) IS
  /* Procedimiento para validar el cobro de comisión por depósito en efectivo, por segmento de clientes
  P_RESPUESTA -> S (cobra comision) / N (no cobra)
  P_VAL_CARGO -> Monto de la comisión + IVA
  P_VAL_TASA  -> Porcentaje de la comisión */ 
                                                     
  v_cod_modulo        ge_cuentas.cod_modulo%TYPE;
  v_cod_modalidad     ge_cuentas.cod_modalidad%TYPE;
  v_cod_oficina       ge_cuentas.cod_oficina%TYPE;
  v_cod_tas_cargo     ge_tasas.cod_tasa%TYPE;
  v_val_tas_cargo     ge_tas_fechas.val_tasa%TYPE;
  v_cod_tas_cargo_cta ge_tasas.cod_tasa%type;
  v_cod_tas_impuesto  ge_tasas.cod_tasa%TYPE;
  v_val_tas_impuesto  ge_tas_fechas.val_tasa%TYPE;
  v_cod_tra_impuesto  ge_transacciones.cod_transaccion%TYPE;
  v_val_impuesto      NUMBER(18, 2);
  v_mto_exonerado     NUMBER(21, 2);
  v_val_base          NUMBER(18, 2) := p_monto;
  v_fec_vigencia      DATE;
  v_tip_valor         VARCHAR2(1);
  v_tipo              VARCHAR2(1);
  v_redondeo          NUMBER(1);
  v_tas_personalizada VARCHAR2(1);
  v_cod_cliente       ge_clientes.cod_persona%TYPE;
  v_segmento          ge_clientes.cod_seg_cliente%TYPE;
  v_cod_tra_cargo     ge_transacciones.cod_transaccion%TYPE := NVL(fug_obt_pardinamico('COB_CARGO_TRX_ME'),5068);--transaccion para cobro de comisión
  v_existe            varchar2(1) := 'N';
BEGIN
  --obtener datos de la cuenta
  BEGIN
    SELECT cod_modulo, cod_modalidad, cod_oficina, tas_personalizada
      INTO v_cod_modulo,
           v_cod_modalidad,
           v_cod_oficina,
           v_tas_personalizada
      FROM ge_cuentas
     WHERE nro_cuenta = p_nro_cuenta;
  EXCEPTION
    WHEN no_data_found THEN
      raise_application_error(-20000,
                              'Cuenta ' || p_nro_cuenta || ' no registrada');
  END;
  -- obtengo el monto exonerado en depositos
  v_mto_exonerado := fug_obt_pardinamico('MTO_EXO_DEPOSITOS_ME',
                                         v_cod_modulo,
                                         v_cod_modalidad,
                                         p_cod_moneda,
                                         v_cod_oficina);
  -- busco los montos ingresados en depositos en efectivo para el cliente
  SELECT nvl(v_mto_exonerado, 0) - nvl(SUM(monto), 0)
    INTO v_mto_exonerado
    FROM ge_movimientos c, ge_cta_clientes b, ge_cta_clientes a
   WHERE a.nro_cuenta = p_nro_cuenta
     AND a.relacion = 'P'
     AND b.cod_persona = a.cod_persona
     AND b.relacion = 'P'
     AND c.nro_cuenta = b.nro_cuenta
     AND c.cod_tra_padre IN (351, 352, 350) -- deposito
     AND c.cod_transaccion IN (690, 1690) -- en efectivo
     AND c.cod_moneda = p_cod_moneda
     AND c.monto > 0
     AND c.estado = 'N'
     AND c.reversado = 'N';
  
  IF v_mto_exonerado < 0 THEN
    v_mto_exonerado := 0;
  END IF;
  --Verifica si cobro comisión por Segmento de cliente
  IF nvl(fug_obt_pardinamico('COB_CARGO_ME'), 'N') = 'S' THEN
    --obtener cliente principal
    v_cod_cliente := FUG_OBT_CLI_PRINCIPAL(p_nro_cuenta, 'P');
    --obtener segmento del cliente
    v_segmento    := FUG_OBT_SEG_CLIENTE(v_cod_cliente);
    --Busco el codigo de tasa asignada a la Transacción
    BEGIN
      select cod_tasa
         into v_cod_tas_cargo
         from ge_transacciones
        where cod_modulo = v_cod_modulo
        and   cod_modalidad = v_cod_modalidad
        and   cod_transaccion = v_cod_tra_cargo;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        raise_application_error(-20000,'Tasa para transaccion '||v_cod_tra_cargo||' no registrada.');
    END;
    --verifico si segmento corresponde al cobro de comisión
    BEGIN
       SELECT DISTINCT ('S')
         INTO v_existe
         FROM ge_tas_rangos
        WHERE nvl(cod_modulo, nvl(v_cod_modulo, -1)) = nvl(v_cod_modulo, -1)
          AND nvl(cod_modalidad, nvl(v_cod_modalidad, -1)) = nvl(v_cod_modalidad, -1)
          AND nvl(cod_oficina, nvl(v_cod_oficina, -1)) = nvl(v_cod_oficina, -1)
          AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
          AND cod_tasa = v_cod_tas_cargo
          AND val_hasta = v_segmento
          AND fec_vigencia <= trunc(SYSDATE);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_existe  := 'N';
        v_cod_tra_cargo := 5068; --transaccion original
        v_cod_tas_cargo := null;
    END;
    
    -- veo si la oficina origen se exonera todo el valor
    If v_val_base > v_mto_exonerado then
     -- guardo el redondeo
     v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad, p_cod_moneda);
     v_val_base := v_val_base - v_mto_exonerado;
     -- veo si la cuenta tiene transaccion prohibida
     if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                     v_cod_tra_cargo,
                                     v_cod_modulo,
                                     v_cod_modalidad) = 'N' then
      -- no tiene transaccion prohibida, se calcula
        begin
           select tas_personalizada 
             into v_tas_personalizada 
             from ge_cuentas
             where nro_cuenta = p_nro_cuenta;
        exception
           when no_data_found then
              raise_application_error(-20000,'Cuenta '||p_nro_cuenta||' no registrada');
        end;
        --Si tiene tasa personalizada setea la transaccion original
        if v_tas_personalizada = 'S' then
          --verifico el codigo de tasa para la cuenta
          BEGIN
             SELECT cod_tasa
               INTO v_cod_tas_cargo_cta
               FROM ge_tas_rangos
              WHERE nvl(cod_modulo, nvl(v_cod_modulo, -1)) = nvl(v_cod_modulo, -1)
                AND nvl(cod_modalidad, nvl(v_cod_modalidad, -1)) = nvl(v_cod_modalidad, -1)
                AND nvl(cod_oficina, nvl(v_cod_oficina, -1)) = nvl(v_cod_oficina, -1)
                AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
                AND nro_cuenta = p_nro_cuenta
                AND fec_vigencia <= trunc(SYSDATE);
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              BEGIN
                SELECT cod_tasa
                 INTO v_cod_tas_cargo_cta
                 FROM ge_tas_fechas
                WHERE nvl(cod_modulo, nvl(v_cod_modulo, -1)) = nvl(v_cod_modulo, -1)
                  AND nvl(cod_modalidad, nvl(v_cod_modalidad, -1)) = nvl(v_cod_modalidad, -1)
                  AND nvl(cod_oficina, nvl(v_cod_oficina, -1)) = nvl(v_cod_oficina, -1)
                  AND nvl(cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
                  AND nro_cuenta = p_nro_cuenta
                  AND fec_vigencia <= trunc(SYSDATE);
              EXCEPTION
                  WHEN NO_DATA_FOUND THEN   
                    raise_application_error(-20000,'No se encuentra tasa para Cuenta '||p_nro_cuenta);
              END;
           END;
          --Si la tasa de la Cuenta <> Tasa por segmento cambio la trx
          if v_cod_tas_cargo_cta <> v_cod_tas_cargo then
            v_cod_tas_cargo := null;
            --Buscar la transaccion relacionada a la tasa
            BEGIN
              SELECT cod_transaccion
               INTO v_cod_tra_cargo
               FROM ge_transacciones
              WHERE cod_modulo = v_cod_modulo
                AND cod_modalidad = v_cod_modalidad
                AND cod_tasa      = v_cod_tas_cargo_cta
                AND tipo  = 'D';
            EXCEPTION
              WHEN TOO_MANY_ROWS THEN
                v_cod_tra_cargo := 597;--TRX utilizada en TED
              WHEN OTHERS THEN
                raise_application_error(-20000,'Eror al buscar transaccion para tasa '||v_cod_tas_cargo_cta||' '||sqlerrm);
            END;
          end if;
        end if;
        -- busco el valor de la tasa 
        if v_tas_personalizada = 'N' and v_existe = 'S' then 
          --busca tasa por segmento
          pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad,
               v_cod_oficina, p_nro_cuenta, p_cod_moneda,
               v_segmento, nvl(v_tas_personalizada,'N'), v_cod_tas_cargo,
               v_cod_tra_cargo, trunc(sysdate),
               v_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT 
        else 
          --busca tasa por monto
          pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad,
               v_cod_oficina, p_nro_cuenta, p_cod_moneda,
               v_val_base, nvl(v_tas_personalizada,'N'), v_cod_tas_cargo,
               v_cod_tra_cargo, trunc(sysdate),
               v_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
        end if;
        p_val_tasa := v_val_tas_cargo;
        if v_tip_valor = 'V' then
           -- si es un valor, se toma directamente
           p_val_cargo := nvl(v_val_tas_cargo,0);
        else
           -- es un porcentaje
           p_val_cargo := round(nvl(v_val_base,0)*
                                   nvl(v_val_tas_cargo,0)/100,v_redondeo);  
          --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
          p_val_cargo := pag_gen.FU_OBT_VAL_FINAL(p_val_cargo);
        end if;
        
        -- busco el impuesto asociado a este cargo
        begin
          select cod_tra_hijo
            into v_cod_tra_impuesto
            from ge_transacciones_det
           where cod_modulo = v_cod_modulo
             and cod_modalidad = v_cod_modalidad
             and cod_transaccion = v_cod_tra_cargo
             and cod_mod_hijo = v_cod_modulo
             and cod_mad_hijo = v_cod_modalidad
             and rownum = 1;
          -- veo si la cuenta tiene exoneracion de impuestos
          if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                          v_cod_tra_impuesto,
                                          v_cod_modulo,
                                          v_cod_modalidad) = 'N' then             
             -- Se encontro impuesto asociado, se calcula
             pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad,
                   v_cod_oficina, p_nro_cuenta, p_cod_moneda,
                   p_val_cargo, nvl(v_tas_personalizada,'N'), v_cod_tas_impuesto,
                   v_cod_tra_impuesto, trunc(sysdate),
                   v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
             if v_tip_valor = 'V' then
                -- si es un valor, se toma directamente
                v_val_impuesto := nvl(v_val_tas_impuesto,0);
             else
                -- es un porcentaje, se considera incluido en el cargo
                v_val_impuesto := round(nvl(p_val_cargo,0)*
                                        nvl(v_val_tas_impuesto,0)/(100+v_val_tas_impuesto),v_redondeo);  
                --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                v_val_impuesto := pag_gen.FU_OBT_VAL_FINAL(v_val_impuesto);
             end if; 

             -- resto el monto del impuesto al cargo, porque va incluido
             p_val_cargo := p_val_cargo - v_val_impuesto;
             if p_val_cargo < 0 then
                raise_application_error(-20000,'Impuesto mas alto que el Cargo');
             end if;   
           else
              v_val_impuesto := 0;  
           end if;   
        exception
           when no_data_found then
              v_val_impuesto := 0;  
           when others then
              raise_application_error(-20000,'Al leer Impuesto '||sqlerrm);
        end;   
     end if;
  end if;

  END IF;
  --respuesta
  if nvl(p_val_cargo,0) > 0 then
    p_respuesta := 'S';
    p_val_cargo := p_val_cargo + v_val_impuesto;
  else
    p_respuesta := 'N';
    p_val_cargo := 0;
    p_val_tasa  := 0;
  end if;
END;
/
