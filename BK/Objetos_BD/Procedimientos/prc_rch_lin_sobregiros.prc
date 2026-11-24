create or replace procedure it.prc_rch_lin_sobregiros is
  cursor lineas is
      select cli.nro_linea, cli.nro_secuencia,cli.rowid fila
        from cc_lin_sobregiros cli
       where estado IN ('I')
         and nro_cuenta is null;
begin
  -- Se debe rechazar todas las lineas de sobregiros pendientes.
  for lin in lineas loop
     update cc_lin_sobregiros
        set estado = 'R',
            cod_usu_autoriza = 'SIS'
      where rowid = lin.fila;
     -- pone como rechazado y borra.
     prc_eli_lin_sobregiro(lin.nro_secuencia, lin.nro_linea);
  end loop;
end;
/

