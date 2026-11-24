CREATE OR REPLACE PROCEDURE IT.PRC_ACT_VEN_SOBREGIRO
  IS
  V_FEC_ACTUAL DATE;
  cursor lineas is
      select cli.nro_linea, cli.nro_secuencia,cli.rowid fila
        from cc_lin_sobregiros cli
       where trunc(cli.fec_vencimiento) < v_fec_actual
         and estado IN ('A','V')
         and nro_cuenta is null; 
begin
  v_fec_actual := PAG_CAL.FU_OBT_FEC_ACTUAL(4);
  for lin in lineas loop
     update cc_lin_sobregiros set estado = 'V'
     where rowid = lin.fila;
     prc_eli_lin_sobregiro(lin.nro_secuencia, lin.nro_linea);
  end loop;
end;
/

