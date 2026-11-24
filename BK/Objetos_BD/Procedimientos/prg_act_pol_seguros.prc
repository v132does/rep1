CREATE OR REPLACE PROCEDURE IT.PRG_ACT_POL_SEGUROS
 IS
 --cursor polisas vencidas
 CURSOR polisas is
   select p.nro_poliza, p.fec_final, p.codigo
     from ge_pol_seguros p
    where p.estado = 2
      and p.fec_final <= pag_cal.FU_OBT_FEC_ACTUAL(1);
  --variables
  v_fec_actual GE_CALENDARIOS.FEC_ACTUAL%TYPE;
Begin
  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
  for po in polisas loop
     if po.fec_final <= v_fec_actual then
         update ge_pol_seguros s
            set s.estado = 3,
                s.situacion = 2
          where s.codigo = po.codigo
            and s.nro_poliza = po.nro_poliza
            and s.estado = 2;
     end if;
  end loop;
Exception
  when no_data_found then
      null;
  when others then
      raise_application_error(-20000,sqlerrm);
End;
/

