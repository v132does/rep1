CREATE OR REPLACE PROCEDURE IT.PRG_GEN_LIS_PREF is
  -- Procedimiento de envio de mensajes
  v_fec_cal    date := pag_cal.fu_obt_fec_actual(1);
  /*
  v_fec_actual date;
  v_mes        varchar2(2);
  v_ano        varchar2(4);
  v_hoy        varchar2(1) := 'N';
  v_hor_inicio date;
  v_hor_fin    date;
  v_det_error  varchar2(100);
  */
  
begin

  if pag_cal.fu_obt_fec_ant_hab(to_date(15 || to_char(v_fec_cal, 'MMYYYY'), 'DDMMYYYY'), null, 0) = v_fec_cal then
    prg_env_mail_pref('M');
  end if;
  
  --Para realizar el envío diario, se deja preparada la funcionalidad por si se solicite       
  /*
  begin
    select 'S'
      into v_hoy
      from ba_personas a,
           ba_per_fisicas pf,
           ge_clientes cli,
           ge_cta_clientes cta,
           ba_direcciones direc,
           (select ax.cod_persona,
                   ax.direccion || ' ' || ax.det_direccion dire
              from ge_ext_clientes ax
             where ax.fec_extracto = (select max(xx.fec_extracto) from ge_ext_clientes xx)
               and ax.cod_extracto = 1) dir,
           ba_telefonos tel,
           (select telc.cod_persona, telc.telefono, telc.area
              from ba_telefonos telc
             where telc.tipo      = 'P'
               and telc.tip_linea = 'C') tela
     where a.cod_persona          = cli.cod_persona
       and a.cod_persona          = pf.cod_persona
       and cli.cod_persona        = pf.cod_persona
       and cta.cod_persona        = cli.cod_persona
       and cli.cli_especial       = 'S'
       and dir.cod_persona (+)    = a.cod_persona
       and tela.cod_persona(+)    = a.cod_persona
       and a.cod_persona          = direc.cod_persona
       and direc.principal        = 'S'
       and cli.cod_seg_preferente in (1, 2)
       and tel.cod_persona        = a.cod_persona
       and tel.principal          = 'S'
       and to_char(pf.fec_nacimiento, 'DD/MM') = to_char(to_date('20/06/2011'), 'DD/MM') --to_char(to_date(sysdate),'DD/MM')
       and exists (select 1
                     from ge_paq_clientes pq
                    where pq.estado      = 'N'
                      and pq.cod_persona = a.cod_persona
                      and pq.cod_paquete in (3, 4))
     group by a.nom_completo,
              pf.fec_nacimiento,
              nvl(dir.dire, direc.direccion),
              to_char(tel.area) || '-' || to_char(tel.telefono),
              a.cod_persona,
              cli.cod_seg_preferente
     order by cli.cod_seg_preferente, pf.fec_nacimiento desc;
  exception
    when no_data_found then
      v_hoy := 'N';
  end;

  if v_hoy = 'S' then
    PRG_ENV_MAIL_PREF('D');
  end if;
  */

  commit;
  --
exception
  when others then
    raise_application_error(-20000, 'Error al Generar listado. ' || sqlerrm);
end;
/

