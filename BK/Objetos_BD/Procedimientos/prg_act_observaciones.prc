CREATE OR REPLACE PROCEDURE IT.PRG_ACT_OBSERVACIONES IS

v_tamano number(4):= 990;
v_tamano_his number(4):= 3990;
v_posicion number(4);
v_cadena varchar2(4000);

cursor cgarantias is
       select * from pr_garantias p where length( p.observacion ) > v_tamano;

cursor cgar_cash is
       select * from pr_gar_cash n where length( n.observacion ) > v_tamano;

cursor cgar_documentos is
       select * from pr_gar_documentos where length( observacion ) > v_tamano;

cursor cgar_standbys is
       select * from pr_gar_standbys where length( observacion ) > v_tamano;

cursor clin_sobregiros is
       select * from cc_lin_sobregiros where length( observacion) > v_tamano;

BEGIN

    pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;

    -- Vaciar historico de Garantias si llego a 4000 caracteres
    update PR_GARANTIAS p
       set p.observacion_his = Null
     WHERE length (p.observacion_his) >= v_tamano_his
        or ( length(p.observacion_his) + length(p.observacion) ) >= v_tamano_his;

    for a in cgarantias loop
        v_posicion := fup_obt_string( 'pr_garantias', 'nro_garantia', 0, 0,
                      a.nro_garantia, 0, 0, 0, 1 );
        v_cadena := fup_obt_string( 'pr_garantias', 'nro_garantia', 0, 0, a.nro_garantia, 0, 0, 1, 0 );
        update PR_GARANTIAS p
           set p.observacion_his = decode(p.observacion_his,null,p.observacion,p.observacion_his||'/- '||trunc (sysdate)||' -/'||substr(p.observacion, 1, v_posicion ) ),
               p.observacion = v_cadena
         WHERE p.nro_garantia = a.nro_garantia;
    end loop;

    -- Vaciar historico de Garantias si llego a 4000 caracteres
    update PR_GAR_CASH n
       set n.observacion_his = Null
     WHERE length (n.observacion_his) >= v_tamano_his
        or ( length(n.observacion_his) + length(n.observacion) ) >= v_tamano_his;

    for b in cgar_cash loop
      v_posicion := fup_obt_string( 'pr_gar_cash', 'nro_garantia', 'serie', 'nro_certificado',
                    b.nro_garantia, b.serie, b.nro_certificado, 0, 1 );
      v_cadena := fup_obt_string( 'pr_gar_cash', 'nro_garantia', 'serie', 'nro_certificado', b.nro_garantia, b.serie, b.nro_certificado, 1, 0 );
      update PR_GAR_CASH n
         set n.observacion_his = decode(n.observacion_his,null,n.observacion,n.observacion_his||'/- '||trunc(sysdate)||' -/'||substr( n.observacion, 1, v_posicion ) ),
             n.observacion = v_cadena
       WHERE n.nro_garantia = b.nro_garantia
         and n.serie = b.serie
         and n.nro_certificado = b.nro_certificado;
    end loop;

    -- Vaciar historico de Garantias si llego a 4000 caracteres
    update PR_GAR_DOCUMENTOS m
       set m.observacion_his = Null
     WHERE length (m.observacion_his) >= v_tamano_his
        or ( length(m.observacion_his) + length(m.observacion) ) >= v_tamano_his;

    for c in cgar_documentos loop
      v_posicion := fup_obt_string( 'pr_gar_documentos', 'nro_garantia', 'nro_secuencia', 0,
                    c.nro_garantia, c.nro_secuencia, 0, 0, 1 );
      v_cadena := fup_obt_string( 'pr_gar_documentos', 'nro_garantia', 'nro_secuencia', 0, c.nro_garantia, c.nro_secuencia, 0, 1, 0 );
      update PR_GAR_DOCUMENTOS m
         set m.observacion_his = decode(m.observacion_his,null,m.observacion, m.observacion_his||'/- '||trunc(sysdate)||' -/'||substr( m.observacion, 1, v_posicion ) ),
             m.observacion = v_cadena
       WHERE m.nro_garantia = c.nro_garantia
         and m.nro_secuencia = c.nro_secuencia;
    end loop;

    -- Vaciar historico de Garantias si llego a 4000 caracteres
    update PR_GAR_STANDBYS l
       set l.observacion_his = Null
     WHERE length (l.observacion_his) >= v_tamano_his
        or ( length(l.observacion_his) + length(l.observacion) ) >= v_tamano_his;

    for d in cgar_standbys loop
      v_posicion := fup_obt_string( 'pr_gar_standbys', 'nro_garantia', 'nro_referencia', 0,
                    d.nro_garantia, d.nro_referencia, 0, 0, 1 );
      v_cadena := fup_obt_string( 'pr_gar_standbys', 'nro_garantia', 'nro_referencia', 0, d.nro_garantia, d.nro_referencia, 0, 1, 0 );
      update PR_GAR_STANDBYS l
         set l.observacion_his = decode(l.observacion_his,null,l.observacion, l.observacion_his||'/- '||trunc(sysdate)||' -/'||substr( l.observacion, 1, v_posicion ) ),
             l.observacion = v_cadena
       WHERE l.nro_garantia = d.nro_garantia
         and l.nro_referencia = d.nro_referencia;
    end loop;

    -- Vaciar historico de Garantias si llego a 4000 caracteres
    update CC_LIN_SOBREGIROS k
       set k.observacion_his = Null
     WHERE length (k.observacion_his) >= v_tamano_his
        or ( length(k.observacion_his) + length(k.observacion) ) >= v_tamano_his;

    for e in clin_sobregiros loop
      v_posicion := fup_obt_string( 'cc_lin_sobregiros', 'nro_secuencia', 0, 0,
                    e.nro_secuencia, 0, 0, 0, 1 );
      v_cadena := fup_obt_string( 'cc_lin_sobregiros', 'nro_secuencia', 0, 0, e.nro_secuencia, 0, 0, 1, 0 );
      update CC_LIN_SOBREGIROS k
         set k.observacion_his = decode(k.observacion_his,null,k.observacion, k.observacion_his||'/- '||trunc(sysdate)||' -/'||substr( k.observacion, 1, v_posicion ) ),
             k.observacion = v_cadena
       WHERE k.nro_secuencia = e.nro_secuencia;
    end loop;

EXCEPTION
    WHEN OTHERS THEN
        raise_application_error(-20000, 'Error desconocido ' || SQLERRM);
END;
/

