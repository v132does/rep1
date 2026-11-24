CREATE OR REPLACE PROCEDURE IT.PRC_ACT_EST_SOBREGIRO IS
  V_FEC_ACTUAL DATE;
  v_cantidad   number(10);
  cursor lineas is
    select cli.tipo, cli.nro_linea, cli.nro_secuencia, cli.rowid fila
      from cc_lin_sobregiros cli
     where trunc(cli.fec_vencimiento) < v_fec_actual;
begin
  v_fec_actual := PAG_CAL.FU_OBT_FEC_ACTUAL(4);
  for lin in lineas loop
    update cc_lin_sobregiros set estado = 'V' where rowid = lin.fila;
    if lin.tipo = 'P' then
          -- Verifica si tiene linea de crédito --
          Select count(*)
            into v_cantidad
            from pr_lineas l, cc_lin_sobregiros s
           where l.nro_linea = s.nro_linea
             and l.nro_linea = lin.nro_linea;
          if v_cantidad > 0 then
            -- Realiza la desafectación del limite y el pase a historico --
            prc_eli_lin_sobregiro(lin.nro_secuencia, lin.nro_linea);
            prp_rec_apl_limite(lin.nro_linea);
          end if;          
     end if;     
  end loop;
end;
/

