CREATE OR REPLACE PROCEDURE IT.PRG_ACT_DEV_DIARIO IS
   --- Este procedimiento actualiza el monto devengado diario de las cuentas en las tablas
   --- de resumenes mensuales.
   v_fecha           ge_calendarios.fec_actual%type;
   v_ano             pr_sal_mensuales.ano%type;
   v_mes             pr_sal_mensuales.mes%type;
   v_dia             varchar2(02);
   v_error           varchar2(1000);
   v_dev_no_cobrado  pr_cta_prestamos.dev_no_cobrado%type;
   v_dev_suspenso    pr_cta_prestamos.dev_suspenso%type;
   --- Cursor de devengamientos del dia anterior si se ejecuta en el inicio de día, 
   -- o del día actual si se ejecuta en proceso de importación de archivos ofac
   cursor c_devengados is
   select dev.nro_cuenta, cta.cod_modulo, cta.cod_modalidad, cta.cod_oficina,
          dev.tipo, sum(dev.mto_dev_actual) mto_actual
     from pr_cta_prestamos cta, pr_devengados dev
    where cta.nro_cuenta = dev.nro_cuenta
      and dev.fecha = v_fecha
    group by dev.nro_cuenta, cta.cod_modulo, cta.cod_modalidad, cta.cod_oficina,
             dev.tipo;

    TYPE cursor1_type IS TABLE of c_devengados%rowtype;
    reg cursor1_type;

BEGIN
   if nvl(PAE_CNF.G_PROGRAMA,'GPPROFIN') = 'GPPROFIN' then
      --en el inicio de día, fecha anterior
      v_fecha := pag_cal.fu_obt_fec_anterior(6);
   else
      --fecha actual
      v_fecha := pag_cal.fu_obt_fec_actual(6);
   end if;
   v_ano   := to_number(to_char(v_fecha,'YYYY'));
   v_mes   := to_number(to_char(v_fecha,'MM'));
   v_dia   := to_char(v_fecha,'DD');
   --- Actualizar saldos mensuales de prestamos

   pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 6;

   OPEN c_devengados;
   LOOP
      FETCH c_devengados BULK COLLECT INTO reg LIMIT 2000;
         FOR i in 1.. reg.count LOOP
            v_dev_no_cobrado := 0;
            v_dev_suspenso   := 0;
            if reg(i).tipo = 'N' then
               v_dev_no_cobrado := nvl(reg(i).mto_actual,0);
            else
               v_dev_suspenso   := nvl(reg(i).mto_actual,0);
            end if;

            v_error := reg(i).nro_cuenta;
            --actualiza no cobrado o actualiza suspenso           
            if v_dia = '01' then
               update pr_sal_mensuales
                  set dev_nco_dia_01 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_01, 0)),
                      dev_sus_dia_01 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_01,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_01, dev_sus_dia_01)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '02' then
               update pr_sal_mensuales
                  set dev_nco_dia_02 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_02, 0)),
                      dev_sus_dia_02 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_02,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_02, dev_sus_dia_02)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '03' then
               update pr_sal_mensuales
                  set dev_nco_dia_03 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_03, 0)),
                      dev_sus_dia_03 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_03,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_03, dev_sus_dia_03)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '04' then
               update pr_sal_mensuales
                  set dev_nco_dia_04 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_04, 0)),
                      dev_sus_dia_04 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_04,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_04, dev_sus_dia_04)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '05' then
               update pr_sal_mensuales
                  set dev_nco_dia_05 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_05, 0)),
                      dev_sus_dia_05 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_05,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_05, dev_sus_dia_05)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '06' then
               update pr_sal_mensuales
                  set dev_nco_dia_06 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_06, 0)),
                      dev_sus_dia_06 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_06,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_06, dev_sus_dia_06)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '07' then
               update pr_sal_mensuales
                  set dev_nco_dia_07 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_07, 0)),
                      dev_sus_dia_07 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_07,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_07, dev_sus_dia_07)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '08' then
               update pr_sal_mensuales
                  set dev_nco_dia_08 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_08, 0)),
                      dev_sus_dia_08 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_08,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_08, dev_sus_dia_08)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '09' then
               update pr_sal_mensuales
                 set dev_nco_dia_09 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_09, 0)),
                     dev_sus_dia_09 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_09,0), replace(v_dev_suspenso, ',', '.'))
               where nro_cuenta = reg(i).nro_cuenta
                 and ano = v_ano
                 and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_09, dev_sus_dia_09)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '10' then
               update pr_sal_mensuales
                  set dev_nco_dia_10 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_10, 0)),
                      dev_sus_dia_10 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_10,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_10, dev_sus_dia_10)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '11' then
               update pr_sal_mensuales
                  set dev_nco_dia_11 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_11, 0)),
                      dev_sus_dia_11 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_11,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_11, dev_sus_dia_11)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '12' then
               update pr_sal_mensuales
                  set dev_nco_dia_12 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_12, 0)),
                      dev_sus_dia_12 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_12,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_12, dev_sus_dia_12)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '13' then
               update pr_sal_mensuales
                  set dev_nco_dia_13 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_13, 0)),
                      dev_sus_dia_13 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_13,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_13, dev_sus_dia_13)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '14' then
               update pr_sal_mensuales
                  set dev_nco_dia_14 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_14, 0)),
                      dev_sus_dia_14 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_14,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_14, dev_sus_dia_14)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '15' then
               update pr_sal_mensuales
                  set dev_nco_dia_15 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_15, 0)),
                      dev_sus_dia_15 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_15,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_15, dev_sus_dia_15)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '16' then
               update pr_sal_mensuales
                  set dev_nco_dia_16 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_16, 0)),
                      dev_sus_dia_16 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_16,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_16, dev_sus_dia_16)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '17' then
               update pr_sal_mensuales
                  set dev_nco_dia_17 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_17, 0)),
                      dev_sus_dia_17 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_17,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_17, dev_sus_dia_17)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '18' then
               update pr_sal_mensuales
                  set dev_nco_dia_18 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_18, 0)),
                      dev_sus_dia_18 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_18,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_18, dev_sus_dia_18)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '19' then
               update pr_sal_mensuales
                  set dev_nco_dia_19 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_19, 0)),
                      dev_sus_dia_19 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_19,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_19, dev_sus_dia_19)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '20' then
               update pr_sal_mensuales
                  set dev_nco_dia_20 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_20, 0)),
                      dev_sus_dia_20 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_20,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_20, dev_sus_dia_20)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '21' then
              update pr_sal_mensuales
                 set dev_nco_dia_21 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_21, 0)),
                     dev_sus_dia_21 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_21,0), replace(v_dev_suspenso, ',', '.'))
               where nro_cuenta = reg(i).nro_cuenta
                 and ano = v_ano
                 and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_21, dev_sus_dia_21)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '22' then
              update pr_sal_mensuales
                 set dev_nco_dia_22 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_22, 0)),
                     dev_sus_dia_22 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_22,0), replace(v_dev_suspenso, ',', '.'))
               where nro_cuenta = reg(i).nro_cuenta
                 and ano = v_ano
                 and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_22, dev_sus_dia_22)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '23' then
              update pr_sal_mensuales
                 set dev_nco_dia_23 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_23, 0)),
                     dev_sus_dia_23 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_23,0), replace(v_dev_suspenso, ',', '.'))
               where nro_cuenta = reg(i).nro_cuenta
                 and ano = v_ano
                 and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_23, dev_sus_dia_23)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '24' then
              update pr_sal_mensuales
                 set dev_nco_dia_24 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_24, 0)),
                     dev_sus_dia_24 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_24,0), replace(v_dev_suspenso, ',', '.'))
               where nro_cuenta = reg(i).nro_cuenta
                 and ano = v_ano
                 and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_24, dev_sus_dia_24)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '25' then
              update pr_sal_mensuales
                 set dev_nco_dia_25 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_25, 0)),
                     dev_sus_dia_25 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_25,0), replace(v_dev_suspenso, ',', '.'))
               where nro_cuenta = reg(i).nro_cuenta
                 and ano = v_ano
                 and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_25, dev_sus_dia_25)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
           elsif v_dia = '26' then
              update pr_sal_mensuales
                 set dev_nco_dia_26 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_26, 0)),
                     dev_sus_dia_26 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_26,0), replace(v_dev_suspenso, ',', '.'))
               where nro_cuenta = reg(i).nro_cuenta
                 and ano = v_ano
                 and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_26, dev_sus_dia_26)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '27' then
               update pr_sal_mensuales
                  set dev_nco_dia_27 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_27, 0)),
                      dev_sus_dia_27 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_27,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_27, dev_sus_dia_27)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '28' then
               update pr_sal_mensuales
                  set dev_nco_dia_28 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_28, 0)),
                      dev_sus_dia_28 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_28,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_28, dev_sus_dia_28)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '29' then
               update pr_sal_mensuales
                  set dev_nco_dia_29 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_29, 0)),
                      dev_sus_dia_29 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_29,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_29, dev_sus_dia_29)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
            elsif v_dia = '30' then
               update pr_sal_mensuales
                  set dev_nco_dia_30 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_30, 0)),
                      dev_sus_dia_30 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_30,0), replace(v_dev_suspenso, ',', '.'))
                where nro_cuenta = reg(i).nro_cuenta
                  and ano = v_ano
                  and mes = v_mes;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_30, dev_sus_dia_30)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
 
              elsif v_dia = '31' then
                 update pr_sal_mensuales
                    set dev_nco_dia_31 = decode(reg(i).tipo, 'N', replace(v_dev_no_cobrado, ',', '.'), nvl(dev_nco_dia_31, 0)),
                        dev_sus_dia_31 = decode(reg(i).tipo, 'N', nvl(dev_sus_dia_31,0), replace(v_dev_suspenso, ',', '.'))
                  where nro_cuenta = reg(i).nro_cuenta
                    and ano = v_ano
                    and mes = v_mes;
               end if;
               --si no existe para el mes, debe iniciar 
               if sql%rowcount < 1 then
                  insert into pr_sal_mensuales 
                            (nro_cuenta, ano, mes, cod_modulo, cod_modalidad, cod_oficina, 
                             can_dia_acumulado, dev_nco_dia_31, dev_sus_dia_31)
                     values (reg(i).nro_cuenta, v_ano, v_mes, reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_oficina, 
                             0, replace(v_dev_no_cobrado, ',', '.'), replace(v_dev_suspenso, ',', '.'));

                end if;
  
         END LOOP;
      EXIT WHEN c_devengados%NOTFOUND;
   END LOOP;
   close c_devengados;
EXCEPTION
   WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000, 'Act. Dev.Diario Cta. Nro. '||v_error|| '. ' ||SQLERRM);
END;
/
