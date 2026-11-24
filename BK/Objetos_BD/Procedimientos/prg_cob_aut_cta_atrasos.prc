CREATE OR REPLACE PROCEDURE IT.PRG_COB_AUT_CTA_ATRASOS IS
v_est_modulo ba_modulos.estado%type;
v_err_code       NUMBER(5);
v_err_msj        VARCHAR2(4000);
  Cursor cta_atr_con_depositos is
      select t.cod_persona,t.nro_cta_credito,t.cod_modulo
     from ge_cli_cta_atrasos t,ge_cta_dat_adicionales a,ge_cuentas c,ge_par_dinamicos d
    where t.tie_deposito = 'S'
      and t.procesado = 'N'
      and t.nro_cta_credito is not null
      and t.nro_cuenta = a.nro_cuenta(+)
      and a.parametro(+) = 'EXC_COB_24X7'
      and nvl(a.val_parametro,'N') = 'N'
      and t.nro_cta_credito = c.nro_cuenta
      --and nvl(c.cod_sub_modalidad,999) <> 6--Excluye Ctas. Aguinaldo
      and fug_es_empleado(t.cod_persona) = 'N'
      and t.cod_modulo = d.cod_modulo
      and d.parametro = 'MOD_COB_24X7'
      and d.val_parametro = 'S'
      and t.mto_mora > nvl(t.tot_cobrado,0) -- No cobrar doble
      group by t.cod_persona, t.nro_cta_credito,t.cod_modulo
      order by t.cod_persona, t.cod_modulo desc, t.nro_cta_credito;
Begin
 v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(4);
 IF v_est_modulo = 2 then -- Solo ejecutar con modulo Abierto.      
      FOR cta IN cta_atr_con_depositos LOOP
          IF cta.cod_modulo = 15 then
            prv_deb_automatico_24x7(cta.cod_persona, cta.nro_cta_credito);
          END IF;
          IF cta.cod_modulo = 6 then
             prp_deb_automatico_24x7(cta.cod_persona, cta.nro_cta_credito);
          END IF;
          IF cta.cod_modulo = 5 then
            prt_deb_automatico_24x7(cta.cod_persona, cta.nro_cta_credito);
         END IF;
      END LOOP;
   END IF;  
  EXCEPTION
    WHEN OTHERS THEN
      v_err_code := SQLCODE;
      v_err_msj  := substr(sqlerrm, 1, 4000);
      INSERT INTO ge_pro_aut_logs (cod_proceso,nom_proceso,fec_hor_ini,fec_hor_fin,nro_error,men_error)
      VALUES (812, 'PRG_COB_AUT_CTA_ATRASOS', sysdate, sysdate, v_err_code, v_err_msj);
      COMMIT;
End;
/

