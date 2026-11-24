CREATE OR REPLACE PROCEDURE IT.pra_act_tar_debitos IS
   v_err_code NUMBER(5);
   v_err_msj  VARCHAR2(4000);
   v_hor_ini  DATE := SYSDATE;
   v_hor_fin  DATE;
   ---
   v_activa          VARCHAR2(1);
   v_est_solicitud   ah_tar_debitos.cod_est_solicitud%TYPE;
   v_existe          NUMBER;
   v_cod_oficina     ge_cuentas.cod_oficina%TYPE;
   v_tip_tar_debito  ah_tar_debitos.tip_tar_debito%TYPE;
   v_tip_envio       ge_dir_envios.tip_envio%TYPE;
   v_referencia      ge_dir_envios.referencia%TYPE;
   v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
   c_cod_pro_bancard NUMBER(5) := to_number(fug_obt_pardinamico('COD_PRO_BANCARD'));
   v_fec_vencimiento DATE;
   v_nro_bin_mastercard ah_tar_debitos.nro_bin%type :=  fug_obt_parentes(c_cod_pro_bancard,'NRO_BIN_TDD_MASTERCARD'); --SDBIN8TDD-1
   v_nro_bin_mastercard_black ah_tar_debitos.nro_bin%type :=  fug_obt_parentes(c_cod_pro_bancard,'NRO_BIN_TDD_MASTERCARD_BLACK'); --BSEVOCORE-1029
   CURSOR c_tar_debitos IS
      SELECT embozado, adherente, fec_vencimiento, nro_tarjeta, nro_emision, fec_alta, cod_embozado,
             fec_ult_mov_pos, estado, fec_ult_mov_atm, fec_embozado, est_pin
        FROM ah_tar_debitos_nov;
   TYPE cursor_type IS TABLE OF c_tar_debitos%ROWTYPE;
   reg_tar_debitos cursor_type;
   v_nro_tarjeta   ah_tar_debitos_nov.nro_tarjeta%type;
BEGIN
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   END;
   ---
   OPEN c_tar_debitos;
   LOOP
      FETCH c_tar_debitos BULK COLLECT
         INTO reg_tar_debitos LIMIT 3000;
      FOR i IN 1 .. reg_tar_debitos.count LOOP
         BEGIN
            IF length(reg_tar_debitos(i).nro_tarjeta) = 17 THEN
               v_nro_tarjeta := substr(reg_tar_debitos(i).nro_tarjeta, 1, 6)
                             || substr(reg_tar_debitos(i).nro_tarjeta, 8);
            ELSE
               v_nro_tarjeta := reg_tar_debitos(i).nro_tarjeta;
            END IF;
            ---
               -- SDBIN8TDD-1 si es un bin de mastercard, buscar en la tabla de relacion para obt la cuenta real
               if substr(v_nro_Tarjeta, 1,6) in (v_nro_bin_mastercard,v_nro_bin_mastercard_black) then--BSEVOCORE-1029
                 begin
                   v_nro_cuenta := fua_obt_cta_cliente(to_number(substr(v_nro_tarjeta,7,9)),substr(v_nro_tarjeta,1,6));
                 exception
                    when others then  
                        null;
                 end;    
               else
               --             
                 v_nro_cuenta := pag_sue.fu_dec_cuenta(substr(v_nro_tarjeta, 8, 9));
               end if;     
               --
                 
               SELECT COUNT(*)
                 INTO v_existe
                 FROM ge_cuentas
                WHERE nro_cuenta = v_nro_cuenta
                  AND ge_cuentas.cod_modulo IN ('3','4');---DYDMR-10649
               IF v_existe = 0 THEN
                  v_nro_cuenta := pag_sue.fu_dec_cuenta(substr(v_nro_tarjeta, 7, 9));
               END IF;
               v_existe := 0;
               ---
               IF reg_tar_debitos(i).estado = 1 THEN
                  -- Activo
                  v_activa := 'S';
               ELSIF reg_tar_debitos(i).estado = 0 THEN
                  -- bloqueado
                  v_activa := 'N';
               END IF;
               IF reg_tar_debitos(i).estado = 1 THEN
                  -- Activo
                  IF reg_tar_debitos(i).est_pin = 'A' THEN
                     -- Pin activo (Ya esta en poder del cliente)
                     v_est_solicitud := 12; -- Entregado al cliente
                  ELSE
                     v_est_solicitud := NULL; --Se pasa nulo para que mantenga el estado actual
                  END IF;
               END IF;
               -- Verificar si existe el registro en AH_TAR_DEBITOS
               SELECT COUNT(*)
                 INTO v_existe
                 FROM ah_tar_debitos
                WHERE nro_cuenta = v_nro_cuenta
                  AND adherente = reg_tar_debitos(i).adherente
                  AND nro_emision = reg_tar_debitos(i).nro_emision
                  AND nro_bin = substr(v_nro_tarjeta, 1, 6);
               /* Si no existe puede que se haya dado de alta en Infonet directamente, entonces dar
               de alta en IT  */
               IF v_existe = 0 THEN
                  -- dar de alta en IT si tuvo algun movimiento
                  --Traer la oficina de la cuenta
                  BEGIN
                     SELECT cod_oficina
                       INTO v_cod_oficina
                       FROM ge_cuentas
                      WHERE nro_cuenta = v_nro_cuenta;
                  EXCEPTION
                     WHEN OTHERS THEN
                        --raise_application_error(-20000,'Error al traer oficina de la cuenta ' || reg_tar_debitos(i).nro_cuenta||' ' ||sqlerrm);
                        v_cod_oficina := NULL;
                  END;
                  IF v_cod_oficina IS NOT NULL THEN
                     --- Si la cuenta no existe, no procesar el registro
                     -- Traer el codigo del tipo de tarjeta de debito (tipo de embozado)
                     BEGIN
                        SELECT val_minimo
                          INTO v_tip_tar_debito
                          FROM ba_cod_referencias
                         WHERE abreviatura = reg_tar_debitos(i).cod_embozado;
                     EXCEPTION
                        WHEN OTHERS THEN
                           --v_tip_tar_debito := NULL;
                           v_tip_tar_debito := 'X'; --Formato no identificado
                     END;
                     -- Traer la direccion de la cuenta
                     BEGIN
                        SELECT tip_envio, referencia
                          INTO v_tip_envio, v_referencia
                          FROM ge_dir_envios
                         WHERE cod_persona = fug_obt_cli_principal(v_nro_cuenta)
                           AND nro_cuenta = v_nro_cuenta;
                     EXCEPTION
                        WHEN no_data_found THEN
                           BEGIN
                              SELECT tip_envio, referencia
                                INTO v_tip_envio, v_referencia
                                FROM ge_dir_envios
                               WHERE cod_persona = fug_obt_cli_principal(v_nro_cuenta)
                                 AND nro_cuenta IS NULL;
                           EXCEPTION
                              WHEN OTHERS THEN
                                 v_tip_envio  := NULL;
                                 v_referencia := NULL;
                           END;
                        WHEN OTHERS THEN
                           v_tip_envio  := NULL;
                           v_referencia := NULL;
                     END;
                     IF v_referencia IS NULL THEN
                        --si no tiene direccion de envio se asigna Retener en la oficina de la cuenta
                        v_tip_envio  := 'R';
                        v_referencia := v_cod_oficina;
                     END IF;
                     BEGIN
                        v_fec_vencimiento := last_day(to_date(
                                             reg_tar_debitos(i).fec_vencimiento ||
                                             '/01', 'rrrr/mm/dd'));
                     EXCEPTION
                        WHEN OTHERS THEN
                           v_fec_vencimiento := NULL;
                     END;
                     -- Inserta en tabla de tarjetas de debito
                     INSERT INTO ah_tar_debitos
                        (nro_cuenta, tar_activa, fec_ingreso, cod_persona, embozado, cod_usuario,
                         fec_grabacion, adherente, nro_emision, cod_ofi_origen, fec_vencimiento,
                         tip_envio, referencia, cod_est_solicitud, cod_ent_procesadora,
                         tip_tar_debito, nro_tarjeta, cod_est_pin, nro_bin, fec_ult_mov_pos,
                         fec_ult_mov_atm)
                     VALUES
                        (v_nro_cuenta, v_activa, trunc(reg_tar_debitos(i).fec_alta),
                         fug_obt_cli_principal(v_nro_cuenta), reg_tar_debitos(i).embozado, USER,
                         SYSDATE, reg_tar_debitos(i).adherente, reg_tar_debitos(i).nro_emision,
                         v_cod_oficina, v_fec_vencimiento, v_tip_envio, v_referencia,
                         nvl(v_est_solicitud, 4), c_cod_pro_bancard, v_tip_tar_debito,
                         v_nro_tarjeta, reg_tar_debitos(i).est_pin,
                         substr(v_nro_tarjeta, 1, 6),
                         reg_tar_debitos(i).fec_ult_mov_pos, reg_tar_debitos(i).fec_ult_mov_atm);
                  END IF;
               ELSIF v_existe <> 0 THEN
                     BEGIN
                        SELECT val_minimo
                          INTO v_tip_tar_debito
                          FROM ba_cod_referencias
                         WHERE abreviatura = reg_tar_debitos(i).cod_embozado;
                     EXCEPTION
                        WHEN OTHERS THEN
                           v_tip_tar_debito := 'X';--Formato no identificado
                     END;
                     BEGIN
                           v_fec_vencimiento := last_day(to_date(
                                                reg_tar_debitos(i).fec_vencimiento ||
                                                '/01', 'rrrr/mm/dd'));
                     EXCEPTION
                        WHEN OTHERS THEN
                           v_fec_vencimiento := NULL;
                     END;
                  -- ya existe
                  --Actualizar campos de la table AH_tAR_DEBITOS
                  UPDATE ah_tar_debitos
                     SET tar_activa      = v_activa,
                         cod_est_pin     = reg_tar_debitos(i).est_pin,
                         fec_ult_mov_pos = reg_tar_debitos(i).fec_ult_mov_pos,
                         fec_ult_mov_atm = reg_tar_debitos(i).fec_ult_mov_atm,
                         nro_tarjeta     = v_nro_tarjeta,
                  --Agregado pedido Mejoras en Proceso TD Fase1  Jul/2021
                         embozado        = reg_tar_debitos(i).embozado,
                         adherente       = reg_tar_debitos(i).adherente,
                         nro_emision     = reg_tar_debitos(i).nro_emision,
                         fec_vencimiento = v_fec_vencimiento,
                         tip_tar_debito  = v_tip_tar_debito
                   WHERE nro_cuenta = v_nro_cuenta
                     AND adherente = reg_tar_debitos(i).adherente
                     AND nro_emision = reg_tar_debitos(i).nro_emision
                     AND nro_bin = substr(v_nro_tarjeta, 1, 6);
               END IF;
            --END IF;
         EXCEPTION
            WHEN OTHERS THEN
               v_err_code := SQLCODE;
               v_err_msj  := SQLERRM;
               v_hor_fin  := SYSDATE;
               INSERT INTO ta_logs
                  (nom_proceso, fec_hor_ini, fec_hor_fin, nro_error, men_error)
               VALUES
                  ('PRA_ACT_TAR_DEBITOS', v_hor_ini, v_hor_fin, v_err_code,
                   substr(v_err_msj, 1, 400));
         END;
      END LOOP;
      EXIT WHEN c_tar_debitos%NOTFOUND;
   END LOOP;
   COMMIT;
END;
/

