CREATE OR REPLACE PROCEDURE IT.prg_val_pre_aprobados IS
   -- Requerimiento: CNFIDCCP-3.
   -- Fecha: 03/06/2015.
   -- Variables.
   v_existe        number;
   v_cod_persona   ge_pro_pre_aprobados_tmp.cod_persona%type := NULL;
   v_saldo         ge_pro_pre_aprobados_tmp.max_monto%type := 0;
   v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
      
   -- Cursores.
   CURSOR cr_pre_apr_tmp IS
      SELECT * FROM ge_pro_pre_aprobados_tmp;

BEGIN

   -- Verifica los registros.
   FOR reg IN cr_pre_apr_tmp LOOP
      BEGIN
         SELECT INSTR(fug_obt_pardinamico('PRE_COD_CAM_REKUTU',reg.cod_modulo,reg.cod_modalidad, null, reg.cod_oficina),reg.cod_campana)
           INTO v_existe
           FROM dual;
         --
         IF v_existe > 0 AND reg.nro_cta_renovada IS NULL THEN
            raise_application_error(-20000, 'Ingresar el Nro. de Cuenta a ser Renovada (Rekutu), cliente: '||reg.cod_persona ||' '|| SQLERRM);         
         END IF;
         --
         -- Verifica que la cuenta sea valida.
         IF v_existe > 0 AND reg.nro_cta_renovada IS NOT NULL THEN
            -- Verifico que sea del modulo de préstamos.
            SELECT COUNT(1)
              INTO v_existe
              FROM ge_cuentas a
             WHERE a.nro_cuenta = reg.nro_cta_renovada
               AND a.cod_modulo = 6
               AND a.estado NOT IN ('N','I');
            --
            IF v_existe = 0 THEN
               raise_application_error(-20000, 'El Nro. de Cuenta a ser Renovada (Rekutu) no corresponde a un Préstamo Vigente, cliente: '||reg.cod_persona ||' '|| SQLERRM);
            END IF;
            -- Verifico que sea del mismo cliente.
            v_cod_persona := fug_obt_cli_principal(reg.nro_cta_renovada);
            IF reg.cod_persona <> v_cod_persona THEN
               raise_application_error(-20000, 'El Nro. de Cuenta a ser Renovada (Rekutu) debe pertenecer al mismo cliente: '||reg.cod_persona ||' '|| SQLERRM);             
            END IF; 
            -- Verifico el saldo de la operación. No deberá ser superior al monto maximo pre-aprobado otorgado.
            BEGIN
               SELECT NVL(pr.sal_capital,0) + NVL(pr.sal_interes,0)
                 INTO v_saldo           
                 FROM pr_cta_prestamos pr
                WHERE pr.nro_cuenta = reg.nro_cta_renovada
                  AND pr.cod_moneda = v_cod_mon_local;
            EXCEPTION
               WHEN OTHERS THEN
                  v_saldo := 0;
            END;
            --
            IF NVL(v_saldo,0) > NVL(reg.max_monto,0) THEN
               raise_application_error(-20000, 'El Saldo de la Cuenta a ser Renovada(Rekutu) es superior al monto maximo pre-aprobado,cliente:'||reg.cod_persona ||' '|| SQLERRM);   
            END IF;
         END IF;
      END;
   END LOOP;
EXCEPTION
   WHEN dup_val_on_index THEN
      raise_application_error(-20000, 'Registro Duplicado en Archivo.');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'prg_val_pre_aprobados. ' || SQLERRM);
END;
/

