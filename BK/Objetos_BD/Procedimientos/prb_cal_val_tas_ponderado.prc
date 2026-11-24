CREATE OR REPLACE PROCEDURE IT.PRB_CAL_VAL_TAS_PONDERADO IS

v_fecha DATE := pag_cal.FU_OBT_FEC_ANT_HAB(PAG_CAL.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),1);
CURSOR cur_cabecera IS 
SELECT a.cod_modulo, a.cod_moneda,a.codcta, sum(a.monto) Mto_total
   FROM mi_sb_tas_ape_semanales  a
  WHERE a.fec_apertura = v_fecha
    AND (a.cod_modulo in (4, 5) OR
         (a.cod_modulo = 3 and a.cod_modalidad = 31))
   group by a.cod_modulo, a.cod_moneda, a.codcta ;

CURSOR cur_tas_ape_semanales (c_cod_modulo number, c_cod_moneda varchar2, c_codcta VARCHAR2) IS 
 SELECT a.nro_cuenta,a.cod_modulo,a.cod_modalidad,a.cod_moneda,a.fec_apertura,a.monto,a.val_tas_nominal, a.corcod
   FROM mi_sb_tas_ape_semanales  a
  WHERE A.VAL_TAS_NOM_PONDERADO IS NULL
    AND a.fec_apertura = v_fecha
    AND a.cod_moneda = c_cod_moneda
    AND a.codcta = c_codcta
    AND ((a.cod_modulo = c_cod_modulo) OR
        (a.cod_modulo = 3 and a.cod_modalidad = 31 and c_cod_modulo = 3)) ;
v_err_upd EXCEPTION;

BEGIN
   FOR x IN cur_cabecera LOOP
     FOR reg IN cur_tas_ape_semanales(x.cod_modulo, x.cod_moneda, x.codcta) LOOP
       UPDATE mi_sb_tas_ape_semanales s
          SET s.val_tas_nom_ponderado = round(((nvl(reg.monto,0)/nvl(x.mto_total,0))* nvl(reg.val_tas_nominal,1)),16)
        WHERE s.nro_cuenta = reg.nro_cuenta
          AND s.corcod = reg.corcod
          AND s.fec_apertura = reg.fec_apertura;
       IF  SQL%NOTFOUND  THEN 
         RAISE v_err_upd;
       END IF;
     END LOOP;
     commit ;
   END LOOP;
EXCEPTION
  WHEN v_err_upd THEN
     RAISE_APPLICATION_ERROR(-20001,'Error al actualizar la tabla MI_SB_TAS_APE_SEMANALES : '||SQLERRM);
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20002,'Error : '||SQLERRM);
END;
/

