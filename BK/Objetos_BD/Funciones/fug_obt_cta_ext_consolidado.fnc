CREATE OR REPLACE FUNCTION IT.FUG_OBT_CTA_EXT_CONSOLIDADO
 (P_COD_PERSONA IN VARCHAR2,
  P_PROCESO IN VARCHAR2,
  P_FECHA IN DATE DEFAULT NULL
 )
 RETURN VARCHAR2
 IS
v_cuentas varchar2(2000);
v_fec_extracto date;
v_cant number;
BEGIN
  IF P_FECHA IS NULL THEN
     v_fec_extracto := pag_cal.FU_OBT_FEC_ACTUAL(1);
  else
     v_fec_extracto := p_fecha;
  END IF;
  IF P_PROCESO = 'S' THEN--trae la cuenta consolidada
    DECLARE
      CURSOR C_REG_CTA_DESGLOSE IS
      select distinct
           cta.nro_cuenta


      from ge_ext_cli_cuentas cta,
           (select funcionario, cod_extracto,cod_persona, fec_extracto,nom_cliente,
                   direccion, substr(telefono,1,instr(telefono,' ')),telefono, tip_direccion, cli_confidencial, cod_per_empresa,
                   fre_extracto, tip_impresion, cod_oficina
             from ge_ext_clientes x
             where x.cod_persona = P_COD_PERSONA
               and x.fec_extracto = v_fec_extracto) cli,ge_modalidades m
     where cta.cod_persona = cli.cod_persona
       and cta.fec_extracto = v_fec_extracto
       and cta.fre_extracto = cli.fre_extracto
       and cta.fec_extracto = cli.fec_extracto
       and cta.cod_extracto = cli.cod_extracto
       and cta.cod_persona = P_COD_PERSONA
       and cta.cod_modalidad = m.cod_modalidad
       and m.cod_modulo not in (6,5) --CROGENEXT-14 Sergio Servín 07/08/2014
       and fue_per_dat_adicional(cta.COD_PERSONA,'TIP_GEN_EXTRACTOS') = 'C';----CROGENEXT-14 Sergio Servín 07/08/2014

      BEGIN
        v_cant:= 0 ;

        FOR R IN C_REG_CTA_DESGLOSE LOOP
		  --se limita, a 180 cuentas para no desbordar el contenedor de cuentas 03-05-2015| Sergio Servín - CROGENEXT-14
          v_cant := v_cant + 1;
          if v_cant <= 180 then
             v_cuentas := v_cuentas||R.nro_cuenta||'-';
          else
            exit;
          end if;

        END LOOP;

      END;

      return SUBSTR(v_cuentas,1,LENGTH(v_cuentas)-1);
      --return v_cuentas;
   ELSE--NO trae la cuenta consolidada
     DECLARE
      CURSOR C_REG_CTA_UNICA IS
      select distinct
           cta.nro_cuenta
      from ge_ext_cli_cuentas cta
     where cta.cod_persona = P_COD_PERSONA
       and cta.fec_extracto = v_fec_extracto
       and exists (select 1
                     from ge_modalidades m
                    where m.cod_modalidad = cta.cod_modalidad
                      and m.cod_modulo not in (6,5)) --CROGENEXT-14 Sergio Servín 07/08/2014
       and fue_per_dat_adicional(cta.COD_PERSONA,'TIP_GEN_EXTRACTOS') = 'C'----CROGENEXT-14 Sergio Servín 07/08/2014
       and rownum = 1;

      BEGIN
        FOR R IN C_REG_CTA_UNICA LOOP
          v_cuentas := R.NRO_CUENTA;
        END LOOP;
      END;

      return v_cuentas;
   END IF;

END;
/

