CREATE OR REPLACE PROCEDURE IT.PRG_ACT_PRE_APROBADOS is
  v_cod_modalidad ge_modalidades.cod_modalidad%type := 68;
  v_msj_error varchar2(1000);
  error_tasas exception;
  ---
  cursor c_aprobados is
    select b.cod_persona, a.cod_modalidad, a.ind_hab_atm, a.ind_hab_hb,
           a.cod_sub_modalidad,a.denominacion as deno, a.fec_vto_campana,-- PCCFPPTC-1 - 10/2016 --
           b.rowid id
      from ge_pro_pre_aprobados_tmp a, ge_pro_pre_aprobados b
     where a.cod_persona = b.cod_persona
       and b.estado = 'V'
       and a.cod_campana = b.cod_campana
       and a.cod_modulo = b.cod_modulo
       and a.cod_modalidad = b.cod_modalidad
       and a.mto_max_cuota = b.mto_max_cuota
       and a.min_monto = b.min_monto
       and a.max_monto = b.max_monto
       and a.min_plazo = b.min_plazo
       and a.max_plazo = b.max_plazo;

begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
  prg_val_tas_rec_preaprobado(v_msj_error);
  if v_msj_error is null then
    for c in c_aprobados loop
      if c.cod_modalidad != v_cod_modalidad then
         begin
           update ge_pro_pre_aprobados x
              set x.cod_modalidad     = v_cod_modalidad,
                  x.cod_sub_modalidad = c.cod_sub_modalidad, -- PCCFPPTC-1 - 10/2016 --
                  x.ind_hab_atm       = c.ind_hab_atm,
                  x.ind_hab_hb        = c.ind_hab_hb,
                  x.denominacion      = c.deno,
                  x.FEC_VTO_CAMPANA   = c.fec_vto_campana
            where x.cod_persona       = c.cod_persona
              and x.rowid             = c.id;
         exception
           when others then
             raise_application_error(-20000,'Error al actualizar GE_PRO_PRE_APROBADOS '||sqlerrm);
         end;
      else
        begin
          update ge_pro_pre_aprobados x
             set x.ind_hab_atm   = c.ind_hab_atm,
                 x.ind_hab_hb    = c.ind_hab_hb,
                 x.denominacion  = c.deno,
                 x.FEC_VTO_CAMPANA   = c.fec_vto_campana
           where x.cod_persona   = c.cod_persona
             and x.rowid         = c.id;
        exception
          when others then
            raise_application_error(-20001,'Error al actualizar GE_PRO_PRE_APROBADOS '||sqlerrm);
        end;
      end if;
    end loop;
  else
    raise error_tasas;
  end if;
exception
  WHEN error_tasas THEN
     raise_application_error(-20000, v_msj_error);
  WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en PRG_ACT_PRE_APROBADOS. ' || SQLERRM);
end PRG_ACT_PRE_APROBADOS;
/

