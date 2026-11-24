CREATE OR REPLACE PROCEDURE IT.PRL_GEN_RES_OPE_CLIENTE
 IS

   -- Acumula el volumen  de operaciones de cambios por cliente.
   v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);
   v_cod_mon_local    ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
   v_monto            ge_movimientos.monto%type := 0;
   v_cod_persona      ge_movimientos.cod_persona%type;
   v_anho             lc_res_ope_clientes.ano%type := to_char(v_fec_actual,'yyyy');
   v_mes              lc_res_ope_clientes.mes%type := to_char(v_fec_actual,'mm');

   -- Cursor de movimientos diarios.
   CURSOR c_movimientos IS
    SELECT a.fecha, a.hora, a.cod_usuario, a.monto, a.cod_moneda, a.mto_equ_local, a.cotizacion cot_ope,
           a.nro_cuenta, a.cod_persona
      FROM lc_tip_operaciones b, ge_movimientos a
     WHERE a.cod_mod_padre = 7
       AND a.cod_mad_padre IN (71,72,73)
       AND a.cod_moneda <> v_cod_mon_local
       AND a.cod_tip_ope_cambio = b.cod_tip_operacion
       AND a.nro_secuencia IN (1,2)
       AND a.cod_transaccion NOT IN  (760, 783, 784, 785, 942)
       AND a.reversado = 'N'
    UNION
    SELECT a.fecha, a.hora, a.cod_usuario, a.monto, a.cod_moneda, a.mto_equ_local, a.cotizacion cot_ope,
           a.nro_cuenta, a.cod_persona
      FROM ge_movimientos b, ge_movimientos a
     WHERE a.cod_mod_padre = 9
       AND a.cod_tra_padre in (388,486)   -- TRANSF.HB
       AND a.estado = 'N'
       AND a.cod_transaccion = 503
       AND a.monto <> 0
       AND b.cod_mod_padre = 9
       AND b.estado = 'N'
       AND b.cod_transaccion = 602
       AND b.fecha = a.fecha
       AND b.cod_usuario = a.cod_usuario
       AND b.hora = a.hora
       AND b.nro_documento = a.nro_documento
       AND b.cod_moneda <> a.cod_moneda
       AND b.monto <> 0
       AND b.cod_moneda <> v_cod_mon_local
    UNION
    SELECT a.fecha, a.hora, a.cod_usuario, a.monto, a.cod_moneda, a.mto_equ_local, a.cotizacion cot_ope,
           a.nro_cuenta, a.cod_persona
      FROM  ge_movimientos b,ge_movimientos a
     WHERE a.cod_mod_padre = 9 -- CAJA,
       AND a.cod_tra_padre in (388,486)  -- Transf. HB
       AND a.estado = 'N'
       AND a.cod_transaccion = 602
       AND a.monto <> 0
       AND b.cod_mod_padre = 9
       AND b.estado = 'N'
       AND b.cod_transaccion = 503
       AND b.fecha = a.fecha
       AND b.cod_usuario = a.cod_usuario
       AND b.hora = a.hora
       AND b.nro_documento = a.nro_documento
       AND b.cod_moneda <> a.cod_moneda
       AND b.monto <> 0
       AND b.cod_moneda <> v_cod_mon_local

   ---Ajuste Inventario Contable de Cuentas de Resultado---
    --Movimientos de transferencias interbancarias SIPAP--
    --CNFDEEVO-73--
    --Fecha: 25/11/2016
    UNION ALL
    select a.fecha,
           a.hora,
           a.cod_usuario,
           a.monto,
           a.cod_moneda,
           a.mto_equ_local,
           a.cotizacion,
           (case
             when a.cod_transaccion = 602 then --Transf. Enviadas
              a.nro_cuenta
             else
              b.nro_cuenta
           end) as nro_cuenta,
           (case
             when a.cod_transaccion = 602 then
              a.cod_persona
             else
              b.cod_persona
           end) as cod_persona
      from ge_movimientos b, ge_movimientos a
     where a.cod_mad_padre = 455
       and a.cod_tra_padre = 303 --Transf. SIPAP
       and a.estado = 'N'
       and a.cod_transaccion in (602, 196)
       and a.monto <> 0
       and b.cod_mad_padre = 455
       and b.estado = 'N'
       and b.cod_transaccion in (503, 190)
       and b.fecha = a.fecha
       and b.cod_usuario = a.cod_usuario
       and b.hora = a.hora
       and b.nro_documento = a.nro_documento
       and b.cod_moneda <> a.cod_moneda
       and b.monto <> 0
       and b.cod_moneda <> v_cod_mon_local
    UNION ALL
    select a.fecha,
           a.hora,
           a.cod_usuario,
           a.monto,
           a.cod_moneda,
           a.mto_equ_local,
           a.cotizacion,
           (case
             when a.cod_transaccion = 503 then --Transf. Recibidas
              a.nro_cuenta
             else
              b.nro_cuenta
           end) as nro_cuenta,
           (case
             when a.cod_transaccion = 503 then
              a.cod_persona
             else
              b.cod_persona
           end) as cod_persona
      from ge_movimientos b, ge_movimientos a
     where a.cod_mad_padre = 455
       and a.cod_tra_padre = 303 --Transf. SIPAP
       and a.estado = 'N'
       and a.cod_transaccion in (503, 190)
       and a.monto <> 0
       and b.cod_mad_padre = 455
       and b.estado = 'N'
       and b.cod_transaccion in (602, 196)
       and b.fecha = a.fecha
       and b.cod_usuario = a.cod_usuario
       and b.hora = a.hora
       and b.nro_documento = a.nro_documento
       and b.cod_moneda <> a.cod_moneda
       and b.monto <> 0
       and b.cod_moneda <> v_cod_mon_local;
---

BEGIN

   FOR reg IN c_movimientos LOOP

      -- Obtiene el importe en moneda local.
      IF reg.cod_moneda = v_cod_mon_local THEN
         v_monto := NVL(reg.monto,0);
      ELSE
         v_monto := NVL(reg.mto_equ_local,0);
      END IF;

      -- Obtengo el código de la persona.
      IF reg.cod_persona IS NOT NULL THEN
         v_cod_persona := reg.cod_persona;
      ELSE
         IF reg.nro_cuenta IS NOT NULL THEN
            v_cod_persona := fug_obt_cli_principal(reg.nro_cuenta);
         ELSE
            BEGIN
               SELECT ge.cod_persona
                 INTO v_cod_persona
                 FROM ge_par_generales ge;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cod_persona := NULL;
            END;
         END IF;
     END IF;

     -- Inserta el movimiento en la tabla acumulada.
     BEGIN

        UPDATE lc_res_ope_clientes
           SET mto_vol_operaciones = nvl(mto_vol_operaciones,0) + nvl(v_monto,0)
         WHERE ano = v_anho
           AND mes = v_mes
           AND cod_persona = v_cod_persona;

        IF SQL%NOTFOUND THEN
           INSERT INTO lc_res_ope_clientes (ano, mes, cod_persona, mto_vol_operaciones)
           VALUES (v_anho, v_mes, v_cod_persona, v_monto);
        END IF;

     EXCEPTION
        WHEN OTHERS THEN
           NULL;
     END;

   END LOOP;
END;
/

