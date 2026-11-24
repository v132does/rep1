CREATE OR REPLACE PROCEDURE IT.PRP_REV_PRESTAMOS_RES_04(
p_cant_registros in number default null)
is
  v_lugar varchar2(3000);
  v_mensaje varchar2(3000);
  v_cant_reg      number(18);
  v_existe     varchar2(1);
  v_error     varchar2(1):='N';
  v_nro_sol_nueva  varchar2(20);
  v_nro_cuenta  varchar2(20);
   --Variables--
   v_hor_mov_can   VARCHAR2(8);
   v_hor_mov_nue   VARCHAR2(8);
   v_fec_actual     DATE := pag_cal.fu_obt_fec_actual(3);

cursor cur_universo is
   SELECT *
          FROM
            ( select a.nro_cuenta from PR_SOL_REV_RES4 a
                  where a.hor_rev_ant is null
                     and a.hor_rev_nueva is null
                      and nvl(a.rev_cta_ant,'N')= 'N'
                      AND nvl(a.rev_cta_nueva,'N')='N'
                      AND a.error is null
                      union
               --unimos con lo marcado por Digitales
               select v.nro_cuenta
                    from pr_cta_pre_can_res4 v
                      where v.nro_cta_nueva is not null
                         and v.nro_sol_nueva is not null
                         and v.fec_reversion is null
                         and nvl(v.reversado,'N')='R'
                          order by 1)
                WHERE  rownum <= v_cant_reg ;

cursor cur_rev_cancelacion is
   SELECT DISTINCT p.nro_cuenta,
                    p.fecha,
                    p.hora,
                    p.cod_usuario,
                    p.cod_tra_padre,
                    p.cod_mod_padre,
                    p.cod_mad_padre
      from pr_movimientos_his   p
     where p.fecha = to_date('30/03/2020','dd/mm/yyyy')
       and p.cod_usuario = 'PY01061'
       and p.fec_valor = to_date('20/03/2020','dd/mm/yyyy')
       and p.reversado = 'N'
       and p.nro_cuenta= v_nro_cuenta;

cursor cur_rev_generacion                           is
  SELECT DISTINCT z.fecha, z.hora, z.cod_usuario, z.cod_tra_padre, z.cod_mod_padre,
                      z.cod_mad_padre, z.nro_documento
        FROM pr_movimientos_his z
       WHERE  z.fecha = to_date('30/03/2020','dd/mm/yyyy')
            and z.cod_usuario='PY01061'
            and z.nro_documento = v_nro_sol_nueva
            AND z.reversado = 'N';

PROCEDURE pr_ins_log_error(p_nro_cuenta   pr_cta_pre_can_log.nro_cuenta%type,
                              p_mensaje      pr_cta_pre_can_log.msg_error%type)
    is
    pragma autonomous_transaction;
    BEGIN
      BEGIN

         update PR_SOL_REV_RES4 A
          set a.error = p_mensaje,
            a.rev_cta_ant='N',
            a.rev_cta_nueva='N'
           where a.nro_cuenta= p_nro_cuenta;

      EXCEPTION
        WHEN OTHERS THEN
          null;
      END;
      commit; -- este commit solo afecta a la transaccion autonoma
    END;

begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;

  v_cant_reg:=0;
  if nvl(p_cant_registros,0)= 0 then
    v_cant_reg:=30;
  else
    v_cant_reg:=p_cant_registros +1;
  end if;

for z in cur_universo loop
  v_existe:= 'N';
  v_error:='N';
  v_hor_mov_nue:= null;
  v_hor_mov_can:= null;
  v_nro_sol_nueva:=null;
  v_nro_cuenta:= null;
  v_mensaje:= null;
  --Buscamos si existe en la tabla espejo, sino existe no procesamos(Para guardar porque no se procesó)
  begin
    select 'S',a.nro_sol_nueva
     into v_existe, v_nro_sol_nueva
    from pr_cta_pre_can_res4 a
      where a.nro_cta_nueva is not null
         and a.nro_sol_nueva is not null
         and a.nro_cuenta= z.nro_cuenta
         and a.fec_reversion is null
     and a.nro_cuenta not in('0766230554','0766970876','0166228206','1366008480','0766872831') ;
   exception
     when no_data_found then
       v_existe:= 'N';
     when others then
       v_existe:= 'N';
  End;
  v_nro_cuenta:= z.nro_cuenta;
   --Solo si existe se procesa
  if v_existe = 'S' then
     v_lugar:='Proceso de Canc.Cta.Ori.: '||z.nro_cuenta;
     v_hor_mov_can := '10:00:00';
     BEGIN
         for x in cur_rev_cancelacion loop
             v_hor_mov_can := fug_obt_hor_disponible(v_fec_actual, v_hor_mov_can, user, 'N');
            prg_rev_operacion_res4(x.fecha, x.hora, x.cod_usuario, x.cod_mod_padre, x.cod_mad_padre,
                              x.cod_tra_padre, user, v_hor_mov_can, 'N', 'Rev. Prest.Canc.Res 4',
                              NULL);
         end loop;

         v_lugar:='Proceso de Rev.Nueva.Cta: '||z.nro_cuenta;
         v_hor_mov_nue := '11:00:00';
         for y in cur_rev_generacion loop
            v_hor_mov_nue := fug_obt_hor_disponible(v_fec_actual, v_hor_mov_nue, user, 'N');
            --Reversamos nuevo
            prg_rev_operacion(y.fecha, y.hora, y.cod_usuario, y.cod_mod_padre, y.cod_mad_padre,
                              y.cod_tra_padre, user, v_hor_mov_nue, 'N', 'Rev. Prest.Tasa Cero.Res4',
                              NULL);
         end loop;
      Exception
        when others then
           v_error:='S';
           v_mensaje := v_lugar||''|| sqlerrm;
           pr_ins_log_error(z.nro_cuenta, v_mensaje);
          rollback;
      END;
      v_lugar :='Actualizando maestro';
      if v_error='N' then
         update PR_SOL_REV_RES4 A
          set a.error =null,
            a.rev_cta_ant='S',
            a.rev_cta_nueva='S',
            a.hor_rev_ant = v_hor_mov_can      ,
            a.hor_rev_nueva=  v_hor_mov_nue
           where a.nro_cuenta= z.nro_cuenta;
           --Actualizamos la tabla maestra
            update pr_cta_pre_can_res4 d
              set d.reversado='S',
                  d.fec_reversion= sysdate,
                  d.cod_usu_reversion = user,
          d.hor_reversion= v_hor_mov_can
              where d.nro_cuenta= z.nro_cuenta;
             commit;
      end if;
  else
      v_mensaje:='No se encontró la cta: '|| z.nro_cuenta||' en tabla de prest. generados' ;
       pr_ins_log_error(z.nro_cuenta, v_mensaje);
      v_mensaje:= null;
  end if;

end loop;


end PRP_REV_PRESTAMOS_RES_04;
/

