create or replace procedure it.prueba_vale
is
v_tasa number;
v_fecha date;
v_tipo ge_tasas.tipo%type;
v_tip_valor ge_tasas.tip_valor%type;
V_TAS NUMBER :=324;
V_TAS2 NUMBER := 421;
v_monto number;
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  dbms_output.put_line('valores1 '||pag_gen.G_VAL_MINIMO||','||pag_gen.G_VAL_MAXIMO);
  pag_gen.pr_obt_val_tasa(4,
                          41,
                          1,
                          1070079,
                          'GS',
                          NULL,
                          'S',
                          V_TAS,
                          NULL,
                          NULL,
                          v_tasa,
                          v_fecha,
                          v_tip_valor,
                          v_tipo);
  dbms_output.put_line('valores 2'||pag_gen.G_VAL_MINIMO||','||pag_gen.G_VAL_MAXIMO);
   v_monto := pag_gen.FU_OBT_VAL_FINAL(1);
  dbms_output.put_line('val '||v_monto);
  pag_gen.pr_obt_val_tasa(3,
                          31,
                          1,
                          70550,
                          'GS',
                          NULL,
                          'S',
                          V_TAS2,
                          NULL,
                          NULL,
                          v_tasa,
                          v_fecha,
                          v_tip_valor,
                          v_tipo);
  dbms_output.put_line('valores 3'||pag_gen.G_VAL_MINIMO||','||pag_gen.G_VAL_MAXIMO);
  v_monto := pag_gen.FU_OBT_VAL_FINAL(1);
  dbms_output.put_line('val '||v_monto);
end;
/

