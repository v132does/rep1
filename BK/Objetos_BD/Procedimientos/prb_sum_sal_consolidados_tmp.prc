CREATE OR REPLACE PROCEDURE IT.PRB_SUM_SAL_CONSOLIDADOS_TMP
 IS

-- Variables.
v_cod_rubro  cb_sal_oficinas_tmp.cod_rubro%type;
v_fec_actual date := pag_cal.fu_obt_fec_actual(1);

-- Cursores.
CURSOR c_sal_oficinas IS
  SELECT substr(cod_rubro,1,5)||'XXX'||substr(cod_rubro,9) cod_rubro, fecha,
         SUM(nvl(sal_mon_loc_ant,0)) sal_mon_loc_ant,
         SUM(nvl(deb_mon_local,0)) deb_mon_local,
         SUM(nvl(cre_mon_local,0)) cre_mon_local,
         SUM(nvl(sal_mon_rub_ant,0)) sal_mon_rub_ant,
         SUM(nvl(deb_mon_rubro,0)) deb_mon_rubro,
         SUM(nvl(cre_mon_rubro,0)) cre_mon_rubro,
         SUM(nvl(sal_equ_loc_ant,0)) sal_equ_loc_ant,
         SUM(nvl(deb_equ_local,0)) deb_equ_local,
         SUM(nvl(cre_equ_local,0)) cre_equ_local
    FROM cb_sal_oficinas_tmp
   WHERE fecha = v_fec_actual
     AND usu_insercion = USER
     AND substr(cod_rubro,1,8) IN ('31060418','31060422')
   GROUP BY substr(cod_rubro,1,5)||'XXX'||substr(cod_rubro,9), fecha;

-- Proceso Principal.
BEGIN
  /* borro los registros anteriores */
  DELETE cb_sal_consolidados_tmp WHERE usu_insercion  = USER;
  
  /* inserto los saldos por oficina */
  INSERT INTO cb_sal_consolidados_tmp (cod_rubro, fecha, sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_mon_rub_ant,
                                       deb_mon_rubro, cre_mon_rubro, sal_equ_loc_ant, deb_equ_local, cre_equ_local)
       SELECT cod_rubro, fecha,
              SUM(nvl(sal_mon_loc_ant,0)),
              SUM(nvl(deb_mon_local,0)),
              SUM(nvl(cre_mon_local,0)),
              SUM(nvl(sal_mon_rub_ant,0)),
              SUM(nvl(deb_mon_rubro,0)),
              SUM(nvl(cre_mon_rubro,0)),
              SUM(nvl(sal_equ_loc_ant,0)),
              SUM(nvl(deb_equ_local,0)),
              SUM(nvl(cre_equ_local,0))
         FROM cb_sal_oficinas_tmp
        WHERE fecha = v_fec_actual
          AND usu_insercion = USER
          AND substr(cod_rubro,1,8) NOT IN ('31060418','31060422')
        GROUP BY cod_rubro, fecha;
  /* utilidad */
  FOR reg IN c_sal_oficinas LOOP
     IF reg.sal_mon_loc_ant + reg.deb_mon_local - reg.cre_mon_local > 0 then
        -- PERDIDA
        v_cod_rubro := REPLACE(reg.cod_rubro,'XXX','422');
     ELSE
        -- GANANCIA
        v_cod_rubro := REPLACE(reg.cod_rubro,'XXX','418');
     END IF;
     --
     INSERT INTO cb_sal_consolidados_tmp(cod_rubro, fecha, sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_mon_rub_ant,
                                     deb_mon_rubro, cre_mon_rubro, sal_equ_loc_ant, deb_equ_local, cre_equ_local)
          VALUES (v_cod_rubro, v_fec_actual, reg.sal_mon_loc_ant, reg.deb_mon_local, reg.cre_mon_local, reg.sal_mon_rub_ant, 
                  reg.deb_mon_rubro, reg.cre_mon_rubro, reg.sal_equ_loc_ant, reg.deb_equ_local, reg.cre_equ_local);
  END LOOP;
END;
/

