CREATE OR REPLACE FUNCTION IT.fug_obt_hora(p_cod_usuario varchar2,
                                           p_nom_secuencia varchar2) RETURN varchar2 is  
      v_hora        ge_movimientos.hora%type;
      v_nro_sec     number;
      v_nro_hor     number;
      v_ind_usuario number;
  begin
      if upper(substr(p_cod_usuario, -1)) in ('B','Y','R') then
        v_ind_usuario := 0;
      else
        v_ind_usuario := substr(p_cod_usuario, -1);
      end if;

      if v_ind_usuario > 0 then
        v_nro_sec := fue_obt_sig_secuencia(p_nom_secuencia || v_ind_usuario);
      elsif v_ind_usuario = 0 then
        v_nro_sec := fue_obt_sig_secuencia(p_nom_secuencia);
      end if;

      v_nro_hor := mod(v_nro_sec, 86400);

      v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
                TO_CHAR(TRUNC(mod(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
                TO_CHAR(mod(v_nro_hor, 60), 'FM00');

      return v_hora;
END;
/

