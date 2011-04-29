package org.caruby.tissue;

import java.io.FileNotFoundException;

import org.jruby.embed.EmbedEvalUnit;
import org.jruby.embed.LocalContextScope;
import org.jruby.embed.LocalVariableBehavior;
import org.jruby.embed.PathType;
import org.jruby.embed.ScriptingContainer;

import edu.wustl.common.domain.AbstractDomainObject;

/**
 * JBridge is the Java facade for caRuby Tissue database operations.
 * 
 * @author loneyf@ohsu.edu
 */
public class JBridge {
    private ScriptingContainer container;
    private Object database;
    private Object facade;
    private final static String FACADE_FILE = "catissue/embed/jbridge.rb";
    
    /**
     * Creates a new JBridge instance.
     * 
     * @throws Exception if caRuby instances cannot be accessed.
     */
    public void JBridge() throws Exception {
        container = new ScriptingContainer();
        // load the JBridge facade definition
        load(FACADE_FILE);
        // the CaTissue::Database instance
        database = container.runScriptlet("CaTissue::Database.instance");
        // the CaTissue::JBridge instance
        facade = container.runScriptlet("CaTissue::JBridge.instance");
    }
    
    /**
     * Saves the given domain object to the database.
     * 
     * @param obj the domain object to save
     * @throws Exception if the domain object cannot be saved
     */
    public void save(AbstractDomainObject obj) throws Exception {
        container.callMethod(database, "save", obj);
    }
    
    /**
     * Creates the given annotation.
     * 
     * @param hook the annotated domain object
     * @param annotation the annotation
     * @throws Exception if the annotation cannot be saved.
     */
    public void createAnnotation(AbstractDomainObject hook, Object annotation) throws Exception {
        container.callMethod(facade, "create_annotation", hook, annotation);
    }
    
    /**
     * Loads the given JRuby file.
     * 
     * @param file the file to load
     * @throws Exception if the file cannot be loaded.
     */
    public void load(String file) throws Exception {
        ScriptingContainer container = new ScriptingContainer(LocalContextScope.SINGLETON, LocalVariableBehavior.TRANSIENT);
        EmbedEvalUnit scriptDef = container.parse(PathType.CLASSPATH, file);
        if (scriptDef == null) {
            throw new FileNotFoundException("caRuby file " + file + " not found on classpath");
        }
        scriptDef.run();
    }
}