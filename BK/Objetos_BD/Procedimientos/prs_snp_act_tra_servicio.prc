create or replace procedure it.prs_snp_act_tra_servicio(  p_tab_cob_servicio in pas_snp.t_tab_cob_servicio,
                                                       p_nro_referencia   in ge_cob_servicios.ref_numerico1%type
                                                       )
is
begin
   if p_tab_cob_servicio.count > 0 then
      for i in p_tab_cob_servicio.FIRST..p_tab_cob_servicio.LAST loop
           update ge_cob_servicios c
              set c.ref_numerico1 = p_nro_referencia
            where c.cod_servicio  = p_tab_cob_servicio( i ).cod_servicio
              and c.tip_cobro     = p_tab_cob_servicio( i ).tip_cobro
              and c.nro_operacion = p_tab_cob_servicio( i ).nro_operacion;
           if sql%notfound then
                -- Si no se actualiza todo el detalle de la recaudación parar el proceso
                raise_application_error(-20001,'No se pudo relacionar la mensajería con el detalle del cobro de servicio. ' ||
                           'Cod. Ser.: ' || p_tab_cob_servicio( i ).cod_servicio || ', ' ||
                           'Tip. Cobro: ' || p_tab_cob_servicio( i ).tip_cobro || ', ' ||
                           'Nro. Ope.: ' || p_tab_cob_servicio( i ).nro_operacion
                          );
           end if;
      end loop;
   else
      raise_application_error(-20002, 'No se han encontrado datos del servicio.');
   end if;
exception
   when others then
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20999, 'Error en PRS_SNP_ACT_TRA_SERVICIO: ' || sqlerrm);
     end if;
end prs_snp_act_tra_servicio;
/

