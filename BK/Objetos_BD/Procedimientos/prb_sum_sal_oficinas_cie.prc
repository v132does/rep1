create or replace procedure it.prb_sum_sal_oficinas_cie is
v_cod_mon_fuerte varchar2(4) := pag_gen.FU_OBT_MON_FUERTE;
v_fec_actual date := pag_cal.fu_obt_fec_actual(2);
/* tomo el año y mes de actual */
v_ano number(4) := to_char(v_fec_actual,'yyyy');
v_mes number(2) := to_char(v_fec_actual,'mm');
cursor cta is
 select a.cod_oficina, b.cod_rub_padre, b.cod_moneda,
        sum(nvl(sal_mon_loc_ant,0)) sal_mon_loc_ant,
        sum(nvl(deb_mon_local,0)) deb_mon_local,
        sum(nvl(cre_mon_local,0)) cre_mon_local,
        sum(nvl(sal_mon_rub_ant,0)) sal_mon_rub_ant,
        sum(nvl(deb_mon_rubro,0)) deb_mon_rubro,
        sum(nvl(cre_mon_rubro,0)) cre_mon_rubro,
        sum(nvl(sal_equ_loc_ant,0)) sal_equ_loc_ant,
        sum(nvl(deb_equ_local,0)) deb_equ_local,
        sum(nvl(cre_equ_local,0)) cre_equ_local,
        sum(nvl(sal_ini_mes_mon_local,0)) sal_ini_mes_mon_local,
        sum(nvl(sal_ini_mes_mon_rubro,0)) sal_ini_mes_mon_rubro,
        sum(nvl(sal_ini_mes_mon_fuerte,0)) sal_ini_mes_mon_fuerte,
        sum(nvl(sal_ini_mes_equ_local,0)) sal_ini_mes_equ_local
   from cie_cb_sal_oficinas a,cb_rubros b
  where a.cod_rubro = b.cod_rubro
    and b.imputable = 'S'
   group by a.cod_oficina, b.cod_rub_padre, b.cod_moneda;
v_sal_mon_rub_ant number;
v_deb_mon_rubro number;
v_cre_mon_rubro number;
v_sal_ini_mes_mon_rubro number;

---
PROCEDURE lp_sum_sal_oficinas(WCDOFICI IN NUMBER,
                              WCDCUENT IN CHAR,
                              p_sal_mon_loc_ant in number,
                              p_deb_mon_local in number,
                              p_cre_mon_local  in number,
                              p_sal_mon_rub_ant in number,
                              p_deb_mon_rubro in number,
                              p_cre_mon_rubro in number,
                              p_sal_equ_loc_ant in number,
                              p_deb_equ_local in number,
                              p_cre_equ_local in number,
                              p_sal_ini_mes_mon_local in number,
                              p_sal_ini_mes_mon_rubro in number,
                              p_sal_ini_mes_mon_fuerte in number,
                              p_sal_ini_mes_equ_local in number) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         <<CICLO>> LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                BEGIN
                  ---------------------------------------------------------
                  -- VERIFICA SI EXISTE EN CB_SAL_OFICINAS
                  ---------------------------------------------------------
                  SELECT 'X' INTO WDUMMY
                    FROM CIE_CB_SAL_OFICINAS
                   WHERE COD_OFICINA = WCDOFICI
                     AND COD_RUBRO = CDCUENT
                     AND ANO = v_ano
                     AND MES = v_mes
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   INSERT INTO CIE_CB_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, PROTEGIDO)
                                        VALUES (WCDOFICI, CDCUENT, v_ano, v_mes, 'S');
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - Ofic '||wcdofici||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                    ----------------------------------------
                      UPDATE CIE_CB_SAL_OFICINAS
                        SET sal_mon_loc_ant = nvl(sal_mon_loc_ant,0) + nvl(p_sal_mon_loc_ant,0),
                            deb_mon_local = nvl(deb_mon_local,0) + nvl(p_deb_mon_local,0),
                            cre_mon_local =  nvl(cre_mon_local,0) + nvl(p_cre_mon_local,0),
                            sal_mon_rub_ant = nvl(sal_mon_rub_ant,0) + nvl(p_sal_mon_rub_ant,0),
                            deb_mon_rubro = nvl(deb_mon_rubro,0) + nvl(p_deb_mon_rubro,0),
                            cre_mon_rubro = nvl(cre_mon_rubro,0) + nvl(p_cre_mon_rubro,0),
                            sal_equ_loc_ant = nvl(sal_equ_loc_ant,0) + nvl(p_sal_equ_loc_ant,0),
                            deb_equ_local = nvl(deb_equ_local,0) + nvl(p_deb_equ_local,0),
                            cre_equ_local = nvl(cre_equ_local,0) + nvl(p_cre_equ_local,0),
                            sal_ini_mes_mon_local = nvl(sal_ini_mes_mon_local,0) + nvl(p_sal_ini_mes_mon_local,0),
                            sal_ini_mes_mon_rubro = nvl(sal_ini_mes_mon_rubro,0) + nvl(p_sal_ini_mes_mon_rubro,0),
                            sal_ini_mes_mon_fuerte = nvl(sal_ini_mes_mon_fuerte,0) + nvl(p_sal_ini_mes_mon_fuerte,0),
                            sal_ini_mes_equ_local = nvl(sal_ini_mes_equ_local,0) + nvl(p_sal_ini_mes_equ_local,0)
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                END IF;

             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP CICLO;
      END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuenta');
  END;
---
begin
    -- cero todas las cuentas no imputables
    update cie_cb_sal_oficinas a
       set sal_mon_loc_ant = 0,
             deb_mon_local = 0,
             cre_mon_local = 0,
             sal_mon_rub_ant = 0,
             deb_mon_rubro = 0,
             cre_mon_rubro = 0,
             sal_equ_loc_ant = 0,
             deb_equ_local = 0,
             cre_equ_local = 0,
             sal_ini_mes_mon_local = 0,
             sal_ini_mes_mon_rubro = 0,
             sal_ini_mes_mon_fuerte = 0,
             sal_ini_mes_equ_local = 0
      where exists (select 0 from cb_rubros b
                     where b.cod_rubro = a.cod_rubro
                       and b.imputable = 'N');
   -- sumarizo las cuentas
   for r in cta loop
      v_sal_mon_rub_ant       := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.sal_mon_rub_ant,null,v_fec_actual);
      v_deb_mon_rubro         := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.deb_mon_rubro,null,v_fec_actual);
      v_cre_mon_rubro         := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.cre_mon_rubro,null,v_fec_actual);
      v_sal_ini_mes_mon_rubro := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.sal_ini_mes_mon_rubro,null,v_fec_actual);

      update cie_cb_sal_oficinas
         set sal_mon_loc_ant = sal_mon_loc_ant + r.sal_mon_loc_ant,
             deb_mon_local = deb_mon_local + r.deb_mon_local,
             cre_mon_local = cre_mon_local + r.cre_mon_local,
             sal_mon_rub_ant = sal_mon_rub_ant + v_sal_mon_rub_ant,
             deb_mon_rubro = deb_mon_rubro + v_deb_mon_rubro,
             cre_mon_rubro = cre_mon_rubro + v_cre_mon_rubro,
             sal_equ_loc_ant = sal_equ_loc_ant + r.sal_equ_loc_ant,
             deb_equ_local = deb_equ_local + r.deb_equ_local,
             cre_equ_local = cre_equ_local + r.cre_equ_local,
             sal_ini_mes_mon_local = sal_ini_mes_mon_local + r.sal_ini_mes_mon_local,
             sal_ini_mes_mon_rubro = sal_ini_mes_mon_rubro + v_sal_ini_mes_mon_rubro,
             sal_ini_mes_mon_fuerte = sal_ini_mes_mon_fuerte + r.sal_ini_mes_mon_fuerte,
             sal_ini_mes_equ_local =  sal_ini_mes_equ_local + r.sal_ini_mes_equ_local
       where cod_rubro = r.cod_rub_padre
         and cod_oficina = r.cod_oficina;

      --Si no existe, crear la cuenta padre en cb_sal_oficinas--
      --Finalidad      : Insertar el rubro padre si no existe--
      if sql%notfound then
         insert into cie_cb_sal_oficinas
         (cod_oficina, cod_rubro, ano, mes, protegido,
          sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_mon_rub_ant,
          deb_mon_rubro, cre_mon_rubro, sal_equ_loc_ant, deb_equ_local,
          cre_equ_local, sal_ini_mes_mon_local, sal_ini_mes_mon_rubro,
          sal_ini_mes_mon_fuerte, sal_ini_mes_equ_local)
         values
         (r.cod_oficina, r.cod_rub_padre, v_ano, v_mes, 'S',
          r.sal_mon_loc_ant, r.deb_mon_local, r.cre_mon_local, v_sal_mon_rub_ant,
          v_deb_mon_rubro, v_cre_mon_rubro, r.sal_equ_loc_ant, r.deb_equ_local,
          r.cre_equ_local, r.sal_ini_mes_mon_local, v_sal_ini_mes_mon_rubro,
          r.sal_ini_mes_mon_fuerte, r.sal_ini_mes_equ_local);
      end if;

      -- actualizo los demas padres
   -- se comenta esta linea DYDMR-11364   
  --    dbms_output.put_line(r.cod_rub_padre);
      
      lp_sum_sal_oficinas(r.cod_oficina,
                          r.cod_rub_padre,
                          r.sal_mon_loc_ant ,
                          r.deb_mon_local,
                          r.cre_mon_local,
                          v_sal_mon_rub_ant,
                          v_deb_mon_rubro,
                          v_cre_mon_rubro,
                          r.sal_equ_loc_ant,
                          r.deb_equ_local,
                          r.cre_equ_local,
                          r.sal_ini_mes_mon_local,
                          v_sal_ini_mes_mon_rubro,
                          r.sal_ini_mes_mon_fuerte,
                          r.sal_ini_mes_equ_local);


  end loop;

end;
/

