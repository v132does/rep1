create or replace procedure it.PRG_UPD_HOR_MOV_RES4_V2 is
  v_hora                    ge_movimientos.hora%type := '09:00:00';--to_char(sysdate,'HH24:MI:SS');
  cursor c_prestamos is
    Select * from pr_cta_pre_can_res4 where mov_act = 0;
    /* Select COUNT(*) from ge_movimientos where  trunc(fec_insercion) = trunc(sysdate) - 2
    and (UPPER(concepto) like '%RES%' OR concepto like '%DEV%') order by fec_insercion; --153182*/
begin
   BEGIN   PRE_INI_APLICACION;   PAE_CNF.G_COD_MODULO := 1;  END; 
   FOR p in c_prestamos LOOP
     v_hora := fug_obt_hor_disponible('30/03/2020',v_hora,'PY01061','N');
     BEGIN
       UPDATE ge_movimientos
          SET hora = v_hora
        WHERE fecha = '30.03.2020'
          AND cod_usuario = 'PY01061'
          AND fec_valor = '20/03/2020'
          AND (nro_cuenta = p.nro_cuenta OR concepto like '%'||p.nro_cuenta||'%');
       UPDATE pr_cta_pre_can_res4 r
          SET r.mov_act = 1
        WHERE r.nro_cuenta = p.nro_cuenta;  
       commit;
     exception
        when others then
          raise_application_error(-20001,'v_hora: '||v_hora||' cta: '||p.nro_cuenta||' '||sqlerrm);
     end;
   end loop;
end;
/

