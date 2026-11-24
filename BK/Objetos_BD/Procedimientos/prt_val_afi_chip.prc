CREATE OR REPLACE PROCEDURE IT.PRT_VAL_AFI_CHIP(P_VALOR IN VARCHAR2) IS
 v_cadena     varchar2(100) := p_valor||',';
 v_afi_inexis varchar2(100) := null;
 v_existe     varchar2(1) := 'N';          
 v_afinidad   varchar2(20);              
 v_cant       number := 0;                   
 v_fin        number := 0;
 PRAGMA AUTONOMOUS_TRANSACTION;
 CURSOR afi_chip IS
    SELECT a.val_parametro
      FROM ge_par_dinamicos a
     WHERE a.parametro = 'TRC_TIP_PLA_CHIP'
     ORDER BY a.cod_modalidad;
BEGIN
   SELECT nvl(length(v_cadena) - length(replace(v_cadena, ',', '')), 0)
     INTO v_cant
     FROM dual;
     
   FOR i IN 1..v_cant LOOP
      v_fin := instr(v_cadena, ',');
      v_afinidad := substr(v_cadena, 1, v_fin- 1);
      v_cadena := substr(v_cadena,v_fin+1);
      v_existe := 'N';
      FOR cur IN afi_chip LOOP
          IF instr(','||cur.val_parametro||',', ','||v_afinidad||',') > 0 THEN
             v_existe := 'S';
          END IF;
      END LOOP;
      IF v_existe = 'N' THEN
         v_afi_inexis := v_afi_inexis||','||v_afinidad;
      END IF;
   END LOOP;
   
   v_afi_inexis := substr(v_afi_inexis, 2); --Para sacar la 1ra coma(,)
   IF length(v_afi_inexis) > 0 THEN
      raise_application_error(-20000,'La/s afinidad/es '||v_afi_inexis||' No Esta/n en el parametro TRC_TIP_PLA_CHIP');
   END IF;
END;
/

