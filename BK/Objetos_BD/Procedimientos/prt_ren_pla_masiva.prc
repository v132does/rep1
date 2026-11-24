create or replace procedure it.PRT_REN_PLA_MASIVA is
cont number;
cursor cur_ta_ren_planillas_tmp is
       select * from ta_ren_planillas_tmp a
       where a.estado='Rendida';

cursor cur_pla_tmp is
       select distinct nro_planilla from ta_ren_planillas_tmp b;

fec_actual date:= pag_cal.fu_obt_fec_actual(5);
begin
       for x in cur_ta_ren_planillas_tmp loop
          begin
                 update ta_tarjetas a
                 set a.fec_entrega=fec_actual,
                     a.cod_estado=3
                 where fut_for_tarjeta(a.nro_tarjeta)=x.nro_tarjeta;

           exception
             when others then
                  raise_application_error(-20000,'Error al actualizar NU_TARJETA:'||x.nro_tarjeta||'En ta_tarjetas');
           end;
       end loop;
       commit;
       for y in cur_pla_tmp loop
          cont:=0;
          select count(*) into cont
                 from ta_tarjetas ta
                 where ta.nro_planilla=y.nro_planilla
                 and ta.cod_estado in(2,4);
          if cont=0 then
                 begin
                   update ge_planillas b
                   set b.estado=6,
                       b.cod_usu_rendicion=user
                   where b.nro_planilla=y.nro_planilla;
                   exception
                   when others then
                        raise_application_error(-20000,'Error al actualizar Num_planilla'||y.nro_planilla||'En Ge_Planillas');
                 end;
          end if;
        end loop;
        commit;
exception
       when others then
            raise_application_error(-20000,'Error al ejecutar PRT_REN_PLA_MASIVA'||sqlerrm);


end PRT_REN_PLA_MASIVA;
/

