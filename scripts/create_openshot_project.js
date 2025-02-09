const request = require('request-promise');
require('dotenv').config({ path: '../.env' });

const createOpenshotProject = async () => {
    const protocol = 'http';
    const server = process.env.OPENSHOT_API_URL || '18.119.159.104';
    const token = process.env.OPENSHOT_API_TOKEN;

    if (!token) {
        throw new Error('OPENSHOT_API_TOKEN is required in .env file');
    }

    // Project data for CookCut base project
    const projectData = {
        'name': 'CookCut_Base',
        'width': 1920,
        'height': 1080,
        'fps_num': 30,
        'fps_den': 1,
        'sample_rate': 44100,
        'channels': 2,
        'channel_layout': 3,
        'json': JSON.stringify({
            'app': 'cookcut',
            'version': '1.0.0',
            'created_at': new Date().toISOString(),
            'is_base_project': true
        })
    };

    try {
        // Create the project
        const response = await request({
            method: 'POST',
            uri: `${protocol}://${server}/projects/`,
            headers: {
                'Authorization': `Token ${token}`,
                'Content-Type': 'application/json'
            },
            json: true,
            body: projectData
        });

        console.log('Successfully created base project:');
        console.log('Project ID:', response.id);
        console.log('Project URL:', response.url);
        
        // Save the project details to a file for Flutter app to use
        const fs = require('fs');
        fs.writeFileSync('openshot_project.json', JSON.stringify({
            project_id: response.id,
            project_url: response.url,
            created_at: new Date().toISOString()
        }, null, 2));

        return response;
    } catch (error) {
        console.error('Failed to create project:', error.message);
        throw error;
    }
};

// Run if called directly
if (require.main === module) {
    createOpenshotProject()
        .then(() => console.log('Done'))
        .catch(err => {
            console.error(err);
            process.exit(1);
        });
}

module.exports = { createOpenshotProject }; 