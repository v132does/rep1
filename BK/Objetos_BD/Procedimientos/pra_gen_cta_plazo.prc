CREATE OR REPLACE PROCEDURE IT.pra_gen_cta_plazo(p_tip_capitalizacion ah_cta_plazos.tip_capitalizacion%TYPE,
                                              p_nro_cta_credito    ah_cta_plazos.nro_cta_capitalizacion%TYPE,
                                              p_cod_canal          ah_cta_plazos.cod_canal%TYPE,
                                              p_monto              ah_cta_plazos.capital%TYPE,
                                              p_can_meses          NUMBER,
                                              p_nro_cuenta     OUT ah_cta_plazos.nro_cuenta%TYPE ) IS

  v_cod_persona      ba_personas.cod_persona%TYPE;
  v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
  v_cod_oficina      ge_clientes.cod_oficina%TYPE;
  v_pri_nombre       ba_per_fisicas.pri_nombre%TYPE;
  v_seg_nombre       ba_per_fisicas.seg_nombre%TYPE;
  v_pri_apellido     ba_per_fisicas.pri_apellido%TYPE;
  v_seg_apellido     ba_per_fisicas.seg_apellido%TYPE;
  v_denominacion     cc_cta_corrientes.denominacion%TYPE;
  v_fec_apertura     ah_cta_plazos.fec_vencimiento%TYPE := pag_cal.fu_obt_fec_actual(3);
  v_fec_vencimiento  ah_cta_plazos.fec_vencimiento%TYPE;
  v_sgt_fecha        ah_cta_plazos.fec_vencimiento%TYPE := v_fec_apertura;
  v_fec_vto          ah_cta_plazos.fec_vencimiento%TYPE := v_fec_apertura;
  v_fec_vto_cup      ah_cta_plazos.fec_vencimiento%TYPE;
  v_fec_vto_final    ah_cta_plazos.fec_vencimiento%TYPE;
  v_cod_modulo       ah_cta_plazos.cod_modulo%TYPE := 3;
  v_cod_modalidad    ah_cta_plazos.cod_modalidad%TYPE := 37;
  v_val_tasa         ah_cta_plazos.val_tasa%TYPE;
  v_cod_moneda       ba_monedas.cod_moneda%TYPE;
  v_dia              VARCHAR2(15);
  v_total            NUMBER(18,2) := 0;
  v_plazo            NUMBER(5);
  v_saldo            NUMBER(18,2) := 0;
  v_numero           NUMBER(3) := 0;
  v_interes          NUMBER(18,2);
  v_redondeo         NUMBER(2);
  v_can_dias         NUMBER(5);
  v_dif_dias         NUMBER(5)  := 0;
  v_nro_cupon        NUMBER(3);
  v_can_cupones      NUMBER(3);
  v_int_calculado    NUMBER(18,2);
  v_dia_restantes    NUMBER(5) := 0;
  v_vto_dia_habil    VARCHAR2(1):= 'N';
  v_tip_relacion     VARCHAR2(1);
  
  Cursor c_cli_cuentas is
     Select ct.cod_persona
       From ge_cta_clientes ct
       where ct.nro_cuenta = p_nro_cta_credito
         and ct.relacion   = 'O';

  FUNCTION lf_obt_nombre
   (
      p_pri_nombre   VARCHAR2,
      p_seg_nombre   VARCHAR2,
      p_pri_apellido VARCHAR2,
      p_seg_apellido VARCHAR2,
      p_tamano       NUMBER
   ) RETURN VARCHAR2 IS
      v_nombre VARCHAR2(120);
   BEGIN
      IF length(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
         IF length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
            IF length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
               v_nombre := p_pri_nombre||' '||p_pri_apellido;
            ELSE
               v_nombre := TRIM(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
            END IF;
         ELSE
            v_nombre := TRIM(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
         END IF;
      ELSE
         v_nombre := TRIM(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
      END IF;
      RETURN v_nombre;
   END;
   
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;

   -- Recuperar moneda y titular de la cuenta
   BEGIN
      SELECT a.cod_moneda, fug_obt_cli_principal(a.nro_cuenta)
        INTO v_cod_moneda, v_cod_persona
        FROM ge_cuentas a
       WHERE a.nro_cuenta = p_nro_cta_credito;
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20000,'Error en PRA_GEN_CTA_PLZO. Cuenta '||p_nro_cta_credito||' Inexistente.');
   END;
   
   --Recupera el tip_relacion de la Cta. Origen
   v_tip_relacion := fue_obt_tip_relacion(p_nro_cta_credito);
   
   -- Recuperar oficina del cliente
   BEGIN
      v_cod_oficina := fug_obt_ofi_cliente(v_cod_persona);
   EXCEPTION
      WHEN OTHERS THEN
         v_cod_oficina := fug_obt_ofi_matriz ;
   END;

   --
   v_can_dias := p_can_meses * 30;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad, v_cod_moneda);
   v_fec_vencimiento := v_fec_apertura + v_can_dias;
   v_vto_dia_habil := FUG_OBT_PARDINAMICO('VTO_HAB_CUPON', v_cod_modulo,v_cod_modalidad, v_cod_moneda);
   IF v_vto_dia_habil = 'S' THEN
      v_dia := RTRIM(UPPER(TO_CHAR(v_fec_vencimiento, 'day')));
      IF (v_dia) IN ('SABADO','SATURDAY','SÁBADO') or (v_dia) IN ('SUNDAY','DOMINGO') THEN
         v_fec_vencimiento := PAG_CAL.FU_OBT_FEC_SIG_HAB(v_fec_vencimiento, v_cod_oficina);
  	  END IF;
       --Verificar si es feriado
      IF fue_ctr_fec_feriado(v_fec_vencimiento, v_cod_oficina) THEN
         v_fec_vencimiento := PAG_CAL.FU_OBT_FEC_SIG_HAB(v_fec_vencimiento, v_cod_oficina);
      END IF;
   END IF;

   -- Validaciones
   IF nvl(p_monto, 0) < nvl(fug_obt_pardinamico('MTO_MIN_AHO_PLZ_FIJ_DIGITAL', v_cod_modulo,
                            v_cod_modalidad, v_cod_moneda), 0)  THEN
      raise_application_error(-20000,'Monto no válido o menor al parametro MTO_MIN_AHO_PLZ_FIJ_DIGITAL.');
   END IF;
   IF nvl(v_can_dias, 0) not between nvl(fug_obt_pardinamico('PLZ_MIN_AHO_PLZ_FIJ_DIGITAL'), 0)
                                 and nvl(fug_obt_pardinamico('PLZ_MAX_AHO_PLZ_FIJ_DIGITAL'), 0) THEN
      raise_application_error(-20000,'Plazo no válido o fuera de rango. Parametro: PLZ_MIN_AHO_PLZ_FIJ_DIGITAL - PLZ_MAX_AHO_PLZ_FIJ_DIGITAL.');
   END IF;
   IF p_tip_capitalizacion not in (1, 2, 3, 4, 6, 12, 99) THEN
      raise_application_error(-20000,'Tipo de Capitalización no válida.');
   END IF;

   -- Recuperar Tasa
   v_val_tasa := paw_bas.fu_obt_tas_pizarra(p_can_meses, p_monto, v_cod_moneda, v_cod_modulo, v_cod_modalidad,
                                            null, p_tip_capitalizacion);
   IF nvl(v_val_tasa, 0) = 0 THEN
      raise_application_error(-20000,'No se encontró Tasa.');
   END IF;

   --
   BEGIN
      SELECT a.pri_nombre, a.seg_nombre, a.pri_apellido, a.seg_apellido
        INTO v_pri_nombre, v_seg_nombre, v_pri_apellido, v_seg_apellido
        FROM ba_per_fisicas a
       WHERE a.cod_persona = v_cod_persona;
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20000,'Error en PRA_GEN_CTA_PLZO Persona '||v_cod_persona||' Inexistente, o no es Persona Física.');
   END;

   -- Insertar en AH_CTA_PLAZOS
   BEGIN
      v_denominacion := lf_obt_nombre(v_pri_nombre, v_seg_nombre, v_pri_apellido, v_seg_apellido,65);
      v_nro_cuenta := fug_obt_sig_nro_cuenta(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_cod_persona);
      INSERT INTO ah_cta_plazos
         (nro_cuenta, dig_verificador, cod_modulo, cod_modalidad, cod_oficina, cod_moneda,
          denominacion, fec_apertura, fec_vencimiento, capital, val_tasa, tip_capitalizacion,
          nro_cta_capitalizacion, est_batch, estado, cod_canal, sal_total, sal_tot_batch )
      VALUES
         (v_nro_cuenta, substr(v_nro_cuenta,-1,1), v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda,
          v_denominacion, v_fec_apertura, v_fec_vencimiento, p_monto, v_val_tasa, p_tip_capitalizacion,
          p_nro_cta_credito, 'N', 'N', p_cod_canal, 0, 0);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error al insertar datos en AH_CTA_PLAZOS. Persona = '||v_cod_persona||' '||SQLERRM);
   END;

   -- Insertar en GE_CTA_CLIENTES
   BEGIN
      INSERT INTO ge_cta_clientes
         (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo, cod_modalidad, relacion)
      VALUES
         (v_cod_persona, v_nro_cuenta, substr(v_nro_cuenta,-1,1), v_cod_oficina, v_cod_modulo, v_cod_modalidad, 'P');

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20004, 'Error al insertar datos en GE_CTA_CLIENTES. Persona: '
         ||v_cod_persona||' Cuenta: '||v_nro_cuenta||SQLERRM);
   END;
   
   -- CUENTAS INDISTINTAS
   IF v_tip_relacion = 'O' THEN
      For r_cli_cuentas in c_cli_cuentas loop
         BEGIN
            INSERT INTO ge_cta_clientes
               (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo, cod_modalidad, relacion)
            VALUES
               (r_cli_cuentas.cod_persona, v_nro_cuenta, substr(v_nro_cuenta,-1,1), v_cod_oficina, v_cod_modulo, v_cod_modalidad, 'O');

         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20004, 'Error al insertar datos en GE_CTA_CLIENTES. Persona: '
               ||r_cli_cuentas.cod_persona||' Cuenta: '||v_nro_cuenta||SQLERRM);
         END;
      End Loop;
   END IF;
   --------------------------
   ---- Insertar cupones ----
   --------------------------
   v_saldo         := p_monto;
   v_int_calculado := round(((p_monto * v_can_dias * v_val_tasa)/36500), v_redondeo);
   IF p_tip_capitalizacion = 99 THEN
      v_plazo := v_can_dias;
      v_can_cupones := 1;
   ELSE
      v_plazo  := trunc(v_can_dias / (p_tip_capitalizacion*30))*(p_tip_capitalizacion*30);
      v_can_cupones  := trunc(v_can_dias / (p_tip_capitalizacion *30));
      v_fec_vto_cup := v_fec_apertura + (p_tip_capitalizacion * 30);
      If v_fec_vto_cup > v_fec_apertura + v_can_dias Then
         v_plazo := v_can_dias;
         v_can_cupones := 1;
      End If;
   END IF;
   If v_can_cupones <= 0 Then
      v_can_cupones := 1;
   End If;
   v_fec_vto_final := v_fec_apertura + v_plazo;
   v_total := 0;
   v_nro_cupon  := 1;

   LOOP
      IF p_tip_capitalizacion = 99 THEN
         v_fec_vto_cup := v_fec_apertura + v_can_dias;
         IF v_vto_dia_habil = 'S' THEN
      	    v_dia := RTRIM(UPPER(TO_CHAR(v_fec_vto_cup, 'day')));
            IF (v_dia) IN ('SABADO','SATURDAY','SÁBADO') or (v_dia) IN ('SUNDAY','DOMINGO') THEN
               v_fec_vto_cup := PAG_CAL.FU_OBT_FEC_SIG_HAB(v_fec_vto_cup, v_cod_oficina);
  	        END IF;
            --Verificar si es feriado
            IF fue_ctr_fec_feriado(v_fec_vto_cup, v_cod_oficina) THEN
               v_fec_vto_cup := PAG_CAL.FU_OBT_FEC_SIG_HAB(v_fec_vto_cup, v_cod_oficina);
            END IF;
         END IF;
         v_dif_dias  := v_fec_vto_cup - v_fec_vto;
         v_interes   := round(((p_monto * v_dif_dias * v_val_tasa)/36500), v_redondeo);
      ELSE
         v_fec_vto_cup := v_sgt_fecha+(p_tip_capitalizacion*30);
         IF v_vto_dia_habil = 'S' THEN
      	    v_dia := RTRIM(UPPER(TO_CHAR(v_fec_vto_cup, 'day')));
            IF (v_dia) IN ('SABADO','SATURDAY','SÁBADO') or (v_dia) IN ('SUNDAY','DOMINGO') THEN
               v_fec_vto_cup := PAG_CAL.FU_OBT_FEC_SIG_HAB(v_fec_vto_cup, v_cod_oficina);
  	        END IF;
            --Verificar si es feriado
            IF fue_ctr_fec_feriado(v_fec_vto_cup, v_cod_oficina) THEN
               v_fec_vto_cup := PAG_CAL.FU_OBT_FEC_SIG_HAB(v_fec_vto_cup, v_cod_oficina);
            END IF;
         END IF;
         v_sgt_fecha := v_sgt_fecha+(p_tip_capitalizacion*30);
         v_dif_dias  := v_fec_vto_cup - v_fec_vto;
         v_interes   := round(((p_monto * v_dif_dias * v_val_tasa)/36500), v_redondeo);
      END IF;
      v_nro_cupon := v_nro_cupon + 1;
      v_fec_vto   := v_fec_vto_cup;
      v_numero    := v_numero + 1;

      -- Insertar cupones
      BEGIN
         INSERT INTO ah_cupones (nro_cuenta, tipo, nro_cupon, mto_interes, fec_vencimiento, estado, est_batch)
         VALUES(v_nro_cuenta, 'O', v_numero, v_interes, v_fec_vto_cup, 'E', 'E');
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20004, 'Error al insertar datos en AH_CUPONES. Persona: '
            ||v_cod_persona||' Cuenta: '||v_nro_cuenta||SQLERRM);
      END;

      v_total := v_total + v_interes;
      IF v_nro_cupon > v_can_cupones THEN
         exit;
      END IF;
   END LOOP;

   --- Si existe diferencia de dias entre la fecha de vencimiento y el vencimiento calculado para el cupon
   v_dia_restantes := v_fec_vto_final - v_fec_vto;
   IF p_tip_capitalizacion <> 99 THEN
      v_saldo := v_int_calculado - v_total;
      -- Debe ajustar por más que no tenga días restantes si el ajuste es diferente a 0
      IF v_dia_restantes BETWEEN 1 AND 15 or (v_saldo != 0 and v_dia_restantes = 0) THEN
         BEGIN
            UPDATE ah_cupones
               SET mto_interes = nvl(mto_interes, 0) + nvl(v_saldo,0),
                   fec_vencimiento = v_fec_vto + v_dia_restantes
             WHERE nro_cuenta = v_nro_cuenta
               AND nro_cupon = v_numero;
         EXCEPTION
            WHEN OTHERS THEN
              raise_application_error(-20004, 'Error al actualizar datos en AH_CUPONES. Persona: '
              ||v_cod_persona||' Cuenta: '||v_nro_cuenta||SQLERRM);
         END;
            v_total := v_total + v_saldo;
      END IF;

      IF v_dia_restantes > 15 THEN
         v_numero := v_numero + 1;
         v_total := v_total + v_saldo;
         BEGIN
            INSERT INTO ah_cupones (nro_cuenta, tipo, nro_cupon, mto_interes, fec_vencimiento, estado, est_batch)
            VALUES (v_nro_cuenta, 'O', v_numero, v_saldo, v_fec_vto + v_dia_restantes, 'E', 'E');
         EXCEPTION
            WHEN OTHERS THEN
              raise_application_error(-20004, 'Error al insertar datos en AH_CUPONES. Persona: '
              ||v_cod_persona||' Cuenta: '||v_nro_cuenta||SQLERRM);
         END;
      END IF;
   END IF;
   p_nro_cuenta := v_nro_cuenta;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20004, 'Error en PRA_GEN_CTA_PLZO.'||SQLERRM);
END pra_gen_cta_plazo;
/

